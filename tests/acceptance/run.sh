#!/usr/bin/env bash

echo 'run.sh: running acceptance-tests-drone'

# An array of the suites that were run. Each value is a string like:
# webUILogin
# webUIPrivateLinks
declare -a SUITES_IN_THIS_RUN

# An array of the unique scenarios that failed. Each key is a string like:
# webUILogin/login.feature:50
# webUIPrivateLinks/accessingPrivateLinks.feature:8
declare -A FAILED_SCENARIO_PATHS

# An array of the scenarios that failed, and were not in the expected failures file.
# Each value is a string like:
# webUILogin/login.feature:50
# webUIPrivateLinks/accessingPrivateLinks.feature:8
declare -a UNEXPECTED_FAILED_SCENARIOS

# An array of the scenarios that were in the expected failures file but did not fail
# Each value is a string like:
# webUILogin/login.feature:50
# webUIPrivateLinks/accessingPrivateLinks.feature:8
declare -a UNEXPECTED_PASSED_SCENARIOS

UNEXPECTED_NIGHTWATCH_CRASH=false

yarn run acceptance-tests-drone | tee -a 'logfile.txt'
ACCEPTANCE_TESTS_EXIT_STATUS=${PIPESTATUS[0]}
if [ "${ACCEPTANCE_TESTS_EXIT_STATUS}" -ne 0 ]; then
  echo "The acceptance tests exited with error status ${ACCEPTANCE_TESTS_EXIT_STATUS}"

  FAILED_SCENARIOS="$(grep -F ') Scenario:' logfile.txt)"
  for FAILED_SCENARIO in ${FAILED_SCENARIOS}; do
    if [[ $FAILED_SCENARIO =~ "tests/acceptance/features/" ]]; then
      SUITE_PATH=$(dirname "${FAILED_SCENARIO}")
      SUITE=$(basename "${SUITE_PATH}")
      SCENARIO=$(basename "${FAILED_SCENARIO}")
      SUITE_SCENARIO="${SUITE}/${SCENARIO}"
      # Use the SUITE_SCENARIO as the array key, so that if a SUITE_SCENARIO
      # occurs twice in the loop, it ends up in the array just once.
      FAILED_SCENARIO_PATHS+=(["${SUITE_SCENARIO}"]="failed")
    fi
  done

  if [ ${#FAILED_SCENARIO_PATHS[@]} -eq 0 ]
  then
    # Nightwatch had some problem but there were no failed scenarios reported
    # So the problem is something else.
    # Possibly there were missing step definitions. Or Nightwatch crashed badly, or...
    UNEXPECTED_NIGHTWATCH_CRASH=true
  fi
fi

if [ ${#FAILED_SCENARIO_PATHS[@]} -ne 0 ]
then
  echo "The following scenarios failed:"
  echo "-------------------------------"
  for KEY in "${!FAILED_SCENARIO_PATHS[@]}"; do echo "$KEY"; done
  echo "-------------------------------"
fi

# Work out which suites were run.
# TEST_PATHS = "tests/acceptance/features/webUILogin tests/acceptance/features/webUINotifications"
# or
# TEST_CONTEXT = "webUIFavorites"
if [ -n "${TEST_PATHS}" ]; then
  for TEST_PATH in ${TEST_PATHS}; do
    SUITE=$(basename "${TEST_PATH}")
    SUITES_IN_THIS_RUN+=("${SUITE}")
  done
fi

if [ -n "${TEST_CONTEXT}" ]; then
  SUITES_IN_THIS_RUN+=("${TEST_CONTEXT}")
fi

if [ -n "${EXPECTED_FAILURES_FILE}" ]; then
  echo "Checking expected failures in ${EXPECTED_FAILURES_FILE}"

  # Check that every failed scenario is in the list of expected failures
  # Loop through the keys of the FAILED_SCENARIO_PATHS array (! does that)
  for FAILED_SCENARIO_PATH in "${!FAILED_SCENARIO_PATHS[@]}"; do
    grep "\[${FAILED_SCENARIO_PATH}\]" "${EXPECTED_FAILURES_FILE}" >/dev/null
    if [ $? -ne 0 ]; then
      echo "Error: Scenario ${FAILED_SCENARIO_PATH} failed but was not expected to fail."
      UNEXPECTED_FAILED_SCENARIOS+=("${FAILED_SCENARIO_PATH}")
    fi
  done

  # Check that every relevant scenario in the expected failures file did fail
  while IFS= read -r LINE; do
    # Ignore comment lines (starting with hash) or the empty lines
    if [[ ("${LINE}" =~ ^#) || (-z "${LINE}") ]]; then
      continue
    fi

    if [[ "${LINE}" =~ -\ \[(.*?)] ]]; then
      LINE="${BASH_REMATCH[1]}"
    else
      continue
    fi
    # This should be a suite name (string) like "webUILogin"
    EXPECTED_FAILURE_SUITE=$(dirname "${LINE}")

    for SUITE_IN_THIS_RUN in "${SUITES_IN_THIS_RUN[@]}"; do
      if [ "${SUITE_IN_THIS_RUN}" == "${EXPECTED_FAILURE_SUITE}" ]
      then
        # This line in the expected failures file is for a suite that has been run.
        # So we expect that the scenario in LINE has run and failed.
        # Look for it in keys of the FAILED_SCENARIO_PATHS array (! does that)
        # The string that is echoed is space-separated. A space is added at the end also.
        # Then we look for the line from the expected failures file followed by a space.
        # That ensures that when looking for a specific line number like xyz.feature:12
        # we do not accidentally match xyz.feature:12 that is in xyz.feature:123
        echo "${!FAILED_SCENARIO_PATHS[@]} " | grep "${LINE} " > /dev/null
        if [ $? -ne 0 ]
        then
          echo "Info: Scenario ${LINE} was expected to fail but did not fail."
          UNEXPECTED_PASSED_SCENARIOS+=("${LINE}")
        fi
      fi
    done
  done < "${EXPECTED_FAILURES_FILE}"
fi

if [ ${#UNEXPECTED_FAILED_SCENARIOS[@]} -gt 0 ]; then
  UNEXPECTED_FAILURE=true
else
  UNEXPECTED_FAILURE=false
fi

if [ ${#UNEXPECTED_PASSED_SCENARIOS[@]} -gt 0 ]; then
  UNEXPECTED_SUCCESS=true
else
  UNEXPECTED_SUCCESS=false
fi

if [ "${UNEXPECTED_FAILURE}" = false ] && [ "${UNEXPECTED_SUCCESS}" = false ] && [ "${UNEXPECTED_NIGHTWATCH_CRASH}" = false ]; then
  FINAL_EXIT_STATUS=0
else
  FINAL_EXIT_STATUS=1
fi

if [ "${UNEXPECTED_FAILURE}" = true ]
then
  tput setaf 3; echo "runsh: Total unexpected failed scenarios throughout the test run:"
  tput setaf 1; printf "%s\n" "${UNEXPECTED_FAILED_SCENARIOS[@]}"
else
  tput setaf 2; echo "runsh: There were no unexpected failures."
fi

if [ "${UNEXPECTED_SUCCESS}" = true ]
then
  tput setaf 3; echo "runsh: Total unexpected passed scenarios throughout the test run:"
  tput setaf 1; printf "%s\n" "${UNEXPECTED_PASSED_SCENARIOS[@]}"
else
  tput setaf 2; echo "runsh: There were no unexpected success."
fi

if [ "${UNEXPECTED_NIGHTWATCH_CRASH}" = true ]
then
  tput setaf 3; echo "Unexpected failure or crash of the nightwatch test run"
fi

echo "runsh: Exit code: ${FINAL_EXIT_STATUS}"

# sync the file-system so all output will be flushed to storage.
# In drone we sometimes see that the last lines of output are missing from the
# drone log.
sync

# If we are running in drone CI, then sleep for a bit to (hopefully) let the
# drone agent send all the output to the drone server.
if [ -n "${CI_REPO}" ]
then
  echo "sleeping for 30 seconds at end of test run"
  sleep 30
fi

exit ${FINAL_EXIT_STATUS}
