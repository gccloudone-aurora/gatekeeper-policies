#!/usr/bin/env bats

# Copyright 2021 Open Policy Agent
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      https://can01.safelinks.protection.outlook.com/?url=http%3A%2F%2Fwww.apache.org%2Flicenses%2FLICENSE-2.0&data=05%7C02%7Cwilliam.hearn%40ssc-spc.gc.ca%7C8c6fd63a50e34b954eec08de52013811%7Cd05bc19494bf4ad6ae2e1db0f2e38f5e%7C0%7C0%7C639038362370798045%7CUnknown%7CTWFpbGZsb3d8eyJFbXB0eU1hcGkiOnRydWUsIlYiOiIwLjAuMDAwMCIsIlAiOiJXaW4zMiIsIkFOIjoiTWFpbCIsIldUIjoyfQ%3D%3D%7C0%7C%7C%7C&sdata=aO9ktfobviwR21gHg7uRdHlY3nYFb9SmcCIt5pfwLZ4%3D&reserved=0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

load helpers

WAIT_TIME=300
SLEEP_TIME=5

@test "testing constraint templates" {

  #
  # Iterate policy directories (group/template)
  #
  for policy in ./*/*/ ; do

    # Only treat directories with a template.yaml as policies
    if [[ ! -f "$policy/template.yaml" ]]; then
      continue
    fi

    local policy_group
    policy_group=$(basename "$(dirname "$policy")")

    local template_name
    template_name=$(basename "$policy")

    local kind
    kind=$(yq e .metadata.name "$policy/template.yaml")

    #
    # Only test selected policy groups
    #
    if [[ "$policy_group" != "general" ]] &&
       [[ "$policy_group" != "pod-security-policy" ]] &&
       [[ "$policy_group" != "service-mesh" ]]
    then
      continue
    fi

    echo "running integration test against policy group: $policy_group, constraint template: $template_name"

    #
    # Apply ConstraintTemplate
    #
    wait_for_process ${WAIT_TIME} ${SLEEP_TIME} \
      "kubectl apply -k $policy"

    #
    # Iterate example subdirectories: examples/<example-name>/
    #
    for example in "$policy"/examples/*/ ; do

      if [[ ! -f "$example/constraint.yaml" ]]; then
        echo "Skipping example $example (no constraint.yaml)"
        continue
      fi

      local name
      name=$(yq e .metadata.name "$example/constraint.yaml")

      #
      # Apply Constraint
      #
      wait_for_process ${WAIT_TIME} ${SLEEP_TIME} \
        "kubectl apply -f $example/constraint.yaml"

      #
      # Wait for enforcement
      #
      wait_for_process ${WAIT_TIME} ${SLEEP_TIME} \
        "constraint_enforced $kind $name"

      #
      # Allowed resources
      #
      for allowed in "$example"/allowed.yaml ; do
        if [[ -e "$allowed" ]]; then
          run kubectl apply -f "$allowed"
          assert_match 'created' "$output"
          assert_success
          kubectl delete --ignore-not-found -f "$allowed"
        fi
      done

      #
      # Disallowed resources
      #
      for disallowed in "$example"/disallowed.yaml ; do
        if [[ -e "$disallowed" ]]; then
          run kubectl apply -f "$disallowed"
          assert_match 'denied the request' "$output"
          assert_failure
          kubectl delete --ignore-not-found -f "$disallowed"
        fi
      done

      #
      # Cleanup constraint
      #
      kubectl delete -f "$example/constraint.yaml"
    done

    #
    # Cleanup template
    #
    kubectl delete -k "$policy"
  done
}