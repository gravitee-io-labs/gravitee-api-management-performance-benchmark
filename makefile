# Makefile for running k6 tests

# Usage: make <test name>

# Define the default test name
TEST_NAME ?= 2-api-key
BASE_URL ?= http://localhost:50083
COLOUR_GREEN = \033[0;32m
COLOUR_CYAN = \033[36m
END_COLOUR = \033[0m

.PHONY: help test cleanup list-scenarios create-api deploy-k6-test extract-duration example

# Default target (help)
help:
	@echo "Usage: make <target>"
	@echo "Targets:"
	@echo "  test              Run k6 tests for a specific scenario"
	@echo "  cleanup           Clean up resources created during testing"
	@echo "  list-scenarios    List all available scenarios"
	@echo "  create-api        Create API resources for testing"
	@echo "  example           Show an example using API key"

# List all available scenarios
list-scenarios:
	@echo "Available scenarios:"
	@ls -d scenarios/*/ | xargs -n1 basename | awk '{print "- " $$0}'

# Run k6 tests for a specific scenario
run-test: create-apim-test-config create-k6-test-config wait-for-k6-test-to-finish cleanup-k6-test-config

# Create API resources for testing
create-apim-test-config:
ifndef TEST_NAME
	@echo "Error: Please provide a valid test name."
	@echo "Usage: make create-api TEST-NAME=<your_test_name>"
	@exit 1
else
	@echo "Using APIm Management API at $(COLOUR_CYAN)$(BASE_URL)$(END_COLOUR)\n"; \
	echo "Create the API and get the API ID ..."; \
	API_ID=$$(curl -sS --location "$(BASE_URL)/management/v2/organizations/DEFAULT/environments/DEFAULT/apis/_import/definition" \
		--header 'Content-Type: application/json' \
		--user admin:admin \
		--data '@scenarios/$(TEST_NAME)/api.json' | jq -r '.id'); \
	echo "API ID is $(COLOUR_CYAN)$$API_ID$(END_COLOUR)\n"; \
	curl -sS --request POST --location "$(BASE_URL)/management/v2/organizations/DEFAULT/environments/DEFAULT/apis/$$API_ID/_start" \
		--user admin:admin; \
	echo "Get the Plan ID and Type ..."; \
	PLAN=$$(curl -sS --location "$(BASE_URL)/management/v2/organizations/DEFAULT/environments/DEFAULT/apis/$$API_ID/plans" \
		--user admin:admin); \
	PLAN_ID=$$(jq -r '.data.[0].id' <<< $$PLAN); \
	PLAN_TYPE=$$(jq -r '.data.[0].security.type' <<< $$PLAN); \
	echo "Plan ID is $(COLOUR_CYAN)$$PLAN_ID$(END_COLOUR) and type is $(COLOUR_CYAN)$$PLAN_TYPE$(END_COLOUR)\n"; \
	if [ "$$PLAN_TYPE" == "API_KEY" ]; then \
		echo "Create an Application and get the App ID ..."; \
		APP_ID=$$(curl -sS --location '$(BASE_URL)/management/organizations/DEFAULT/environments/DEFAULT/applications' \
			--header 'Content-Type: application/json' \
			--user admin:admin \
			--data '{ \
				"name": "Sample App", \
				"description": "Sample App used for performance tests" \
			}' | jq -r '.id'); \
		echo "App ID is $(COLOUR_CYAN)$$APP_ID$(END_COLOUR)\n"; \
		echo "Create a Subscription from the App to the API and get the Subscription ID ..."; \
		SUBSCRIPTION_ID=$$(curl -sS --location '$(BASE_URL)/management/v2/organizations/DEFAULT/environments/DEFAULT/apis/$$API_ID/subscriptions' \
			--header 'Content-Type: application/json' \
			--user admin:admin \
			--data '{ \
				"planId": "'$$PLAN_ID'", \
				"applicationId": "'$$APP_ID'" \
			}' | jq -r '.id'); \
		echo "Subscription ID is $(COLOUR_CYAN)$$SUBSCRIPTION_ID$(END_COLOUR)\n"; \
		echo "Get the API Key from the Subscription ..."; \
		API_KEY=$$(curl -sS --location "$(BASE_URL)/management/v2/organizations/DEFAULT/environments/DEFAULT/apis/$$API_ID/subscriptions/$$SUBSCRIPTION_ID/api-keys" \
			--user admin:admin | jq -r '.data.[0].key'); \
		echo "API Key is $(COLOUR_CYAN)$$API_KEY$(END_COLOUR) and adding it as header in k6 test..."; \
		sed -E -i "" "s/^(.*'X-Gravitee-Api-Key': ).*/\\1'$$API_KEY',/" scenarios/$(TEST_NAME)/test.js; \
		echo "\n$(COLOUR_GREEN) --- APIm config creation is done --- $(END_COLOUR)\n"; \
	fi
endif

# Deploy k6 tests
create-k6-test-config:
ifndef TEST_NAME
	@echo "Error: Please provide a valid test name."
	@echo "Usage: make deploy-k6-test TEST-NAME=<your_test_name>"
	@exit 1
else
	@echo "Deploy k6 test script and testrun manifest...\n"
	@kubectl create configmap $(TEST_NAME) --from-file scenarios/$(TEST_NAME)/test.js -n k6-perf-tests
	@kubectl apply -f scenarios/$(TEST_NAME)/k6-testrun.yaml -n k6-perf-tests
	@echo "\n$(COLOUR_GREEN) --- k6 config creation is done, test $(TEST_NAME) is lauched --- $(END_COLOUR)\n"
endif

# Clean up resources created during testing
cleanup-k6-test-config:
ifndef TEST_NAME
	@echo "Error: Please provide a valid test name."
	@echo "Usage: make cleanup TEST-NAME=<your_test_name>"
	@exit 1
else
	@echo "Cleanup k6 test script and testrun manifest...\n"
	@kubectl delete configmap $(TEST_NAME) -n k6-perf-tests
	@kubectl delete -f scenarios/$(TEST_NAME)/k6-testrun.yaml -n k6-perf-tests
	@echo "\n$(COLOUR_GREEN) --- k6 config cleanup is done --- $(END_COLOUR)\n"
endif

# Extract duration from k6 test.js file
wait-for-k6-test-to-finish:
ifndef TEST_NAME
	@echo "Error: Please provide a valid test name."
	@echo "Usage: make extract-duration TEST-NAME=<your_test_name>"
	@exit 1
else
	@echo "Extracting total scenario duration..."
	@TOTAL_DURATION=$$(grep -oE "duration: '[0-9]+[smhd]'" scenarios/$(TEST_NAME)/test.js | awk '{gsub(/[[:punct:]]/, "", $$2); factor = ($$2 ~ /s/) ? 1 : ($$2 ~ /m/) ? 60 : ($$2 ~ /h/) ? 3600 : 86400; sum += substr($$2, 1, length($$2)-1) * factor} END {print sum}'); \
	echo "Total scenario duration is $$TOTAL_DURATION seconds, adding 30 seconds of margin ..."; \
	TOTAL_DURATION=$$(($$TOTAL_DURATION + 30)); \
	echo "Waiting for the test $(TEST_NAME) to finish in $$TOTAL_DURATION seconds ..."; \
	sleep $$TOTAL_DURATION;
	@echo "\n$(COLOUR_GREEN) --- Test $(TEST_NAME) is done ! --- $(END_COLOUR)\n";
endif