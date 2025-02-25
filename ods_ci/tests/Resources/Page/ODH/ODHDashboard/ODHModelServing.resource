*** Settings ***
Documentation    Collection of keywords to interact with Model Serving
Resource       ../../../Page/Components/Components.resource
Resource       ../../../Common.robot
Resource       ODHDataScienceProject/ModelServer.resource
Resource       ODHDataScienceProject/DataConnections.resource
Library        ../../../../../libs/Helpers.py


*** Variables ***
${MS_HEADER_XP}=     xpath=//h1[text()="Model Serving"]
${S3_NAME_DC_INPUT_XP}=          xpath=//input[@aria-label="Field list Name"]
${S3_KEY_DC_INPUT_XP}=          xpath=//input[@aria-label="Field list AWS_ACCESS_KEY_ID"]
${S3_SECRET_DC_INPUT_XP}=          xpath=//input[@aria-label="Field list AWS_SECRET_ACCESS_KEY"]
${S3_ENDPOINT_DC_INPUT_XP}=          xpath=//input[@aria-label="Field list AWS_S3_ENDPOINT"]
${S3_REGION_DC_INPUT_XP}=          xpath=//input[@aria-label="Field list AWS_DEFAULT_REGION"]
${S3_BUCKET_DC_INPUT_XP}=     xpath=//input[@aria-label="Field list AWS_S3_BUCKET"]
${S3_DEFAULT_BUCKET}=    ods-ci-s3
${MS_TABLE_PROJECT}=    /../../td[@data-label="Project"]
${MS_TABLE_STATUS}=    /../../td[@data-label="Status"]
${MS_TABLE_ENDPOINT}=    /../../td[@data-label="Inference endpoint"]
${MS_TABLE_ENDPOINT_INPUT}=    ${MS_TABLE_ENDPOINT}//div[@class="pf-v5-c-clipboard-copy"]//input
${MS_TABLE_DROPDOWN_TOGGLE}=    /../..//td[contains(@class,"pf-v5-c-table__action")]/button
${MS_TABLE_STATUS_SUCCESS}=     //span[contains(@class,"pf-v5-c-icon__content")][contains(@class,"pf-m-success")]
${MS_TABLE_STATUS_FAILURE}=     //span[contains(@class,"pf-v5-c-icon__content")][contains(@class,"pf-m-danger")]
${KSERVE_MODAL_HEADER}=    //header[@class="pf-v5-c-modal-box__header"]/h1[.="Deploy model"]
${KSERVE_RUNTIME_DROPDOWN}=    //span[.="Serving runtime"]/../../..//div[@id="serving-runtime-template-selection"]
${LLM_RESOURCES_DIRPATH}=    ods_ci/tests/Resources/Files/llm
${UWM_ENABLE_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/uwm_cm_enable.yaml
${UWM_CONFIG_FILEPATH}=    ${LLM_RESOURCES_DIRPATH}/uwm_cm_conf.yaml


*** Keywords ***
Open Model Serving Home Page
    [Documentation]    Verifies submenu Settings > "Model Serving" is visible and navigates to page
    SeleniumLibrary.Page Should Contain    Model Serving
    SeleniumLibrary.Click Link      Model Serving
    # Replace sleep with better Wait keyword. Confirm if error page has "Model Serving" h1 element.
    Sleep    1s
    ${loading_error}=    Run Keyword And Return Status
    ...    SeleniumLibrary.Page Should Contain    Problem loading model serving page
    IF    ${loading_error}
        Log    "Page load error encountered"    level=WARN
        SeleniumLibrary.Capture Page Screenshot
        Sleep    5s
        SeleniumLibrary.Reload Page
    END
    Wait for RHODS Dashboard to Load    wait_for_cards=${FALSE}    expected_page=Deployed models
    SeleniumLibrary.Wait Until Page Contains    Manage and view the health and performance of your deployed models.
    ...    timeout=30
    Maybe Wait For Dashboard Loading Spinner Page

Serve Model
    [Documentation]    Deploys a model via the Model Serving page or Model Server section of a DS Project.
    ...    The framework should be either "onnx" or "openvino_ir".
    [Arguments]    ${project_name}    ${model_name}    ${framework}    ${data_connection_name}    ${model_path}
    ...    ${existing_data_connection}=${TRUE}    ${model_server}=Model Serving Test
    # TODO: Does not work if there's already a model deployed
    SeleniumLibrary.Wait Until Page Does Not Contain Element    //article[@id="multi-serving-platform-card"]
    SeleniumLibrary.Wait Until Page Does Not Contain Element    //article[@id="single-serving-platform-card"]
    SeleniumLibrary.Wait Until Page Contains    Deploy model
    SeleniumLibrary.Click Button    Deploy model
    SeleniumLibrary.Wait Until Page Contains Element    xpath://h1[.="Deploy model"]
    Select Project    ${project_name}
    Set Model Name    ${model_name}
    Select Model Server    ${model_server}
    SeleniumLibrary.Wait Until Page Contains Element    xpath://span[.="Model framework (name - version)"]
    Select Framework    ${framework}
    IF    ${existing_data_connection}==${TRUE}
        # Select Radio Button    group_name=radiogroup    value=existing-data-connection-radio
        # Selected by default, let's skip for now
        Select Existing Data Connection    ${data_connection_name}
        Set Folder Path    ${model_path}
    ELSE
        # Existing connection radio is selected by default; for now blindly click on new connection radio
        SeleniumLibrary.Click Element    //input[@id="new-data-connection-radio"]
        # Select Radio Button    group_name=radiogroup    value=new-data-connection-radio
        Set Up New Data Connection    dc_name=${data_connection_name}
        Set Folder Path    ${model_path}
    END
    SeleniumLibrary.Click Button    Deploy
    SeleniumLibrary.Wait Until Page Does Not Contain    xpath://h1[.="Deploy model"]

Select Project
    [Documentation]    Selects a project in the "deploy model" modal.
    ...    If the user has access to a single project or this is being done from within a DSP
    ...    there's no need to do anything but it checks that the project name is the expected one.
    [Arguments]    ${project_name}
    Wait Until Page Contains Element    xpath://span[.="Project"]
    ${choice}=    Run Keyword And Return Status    Page Should Not Contain Element    xpath://span[.="Project"]/../../..//p[.="${project_name}"]
    IF    ${choice}==${TRUE}
        Open Project Options Menu
        Click Element    xpath://li/button[.="${project_name}"]
        Wait Until Page Contains Element    //span[.="Project"]/../../..//span[.="${project_name}"]
        # modal refresh is unreliable
        Sleep    0.5s
    END

Set Model Name
    [Documentation]    Sets the model name in the "deploy model" modal
    [Arguments]    ${model_name}
    Input Text    xpath://input[@id="inference-service-name-input"]    ${model_name}

Select Model Server
    [Documentation]    If there are multiple model servers to choose from, this keyword
    ...    Selects the given one
    [Arguments]    ${model_server}
    ${selectable} =    Run Keyword And Return Status
    ...    Page Should Contain Element     xpath://span[.="Model servers"]/../../..//button[@aria-label="Options menu"]
    IF    ${selectable}==True
        Open Model servers Options Menu  # robocop:disable
        Click Element    xpath=//li/button[.="${model_server}"]
    END

Select Framework
    [Documentation]    Selects the framework in the "deploy model" modal.
    ...    Possible values for now: "onnx", "openvino_ir"
    [Arguments]    ${framework}
    TRY
        Open Model framework (name - version) Options Menu
        Page Should Contain Element    xpath://li/button[contains(., "${framework}")]
        Click Element    xpath://li/button[contains(., "${framework}")]
    EXCEPT
        Log    framework ${framework} does not appear to be supported by the chosen model server
    END

Select Existing Data Connection
    [Documentation]    Selects an existing data connection in the "deploy model" modal.
    [Arguments]    ${data_connection_name}    ${retries}=1
    FOR  ${retry_idx}  IN RANGE  0  1+${retries}
        Open Name Options Menu
        Click Element    xpath://li/button[.="${data_connection_name}"]
        ${selected} =    Run Keyword And Return Status
        ...    Page Should Contain Element    //span[.="Name"]/../../..//button[@aria-label="Options menu"][.="${data_connection_name}"]  #robocop: disable
        IF  ${selected}==${TRUE}
            BREAK
        END
    END

Set Folder Path
    [Documentation]    Sets the given model path in the "deploy model" modal.
    ...    The path is expected to be relative to the S3 bucket being used.
    ...    e.g.: file in root of S3 bucket -> model_path = filename
    ...    e.g.: file in subfolder of S3 bucket -> model_path = subfolder/filename
    [Arguments]    ${model_path}
    Input Text    xpath://input[@placeholder="Example, data_folder"]    ${model_path}

Set Up New Data Connection
    [Documentation]    Fills in details for new data connection in "deploy model" modal
    [Arguments]    ${dc_name}    ${aws_access_key}=${S3.AWS_ACCESS_KEY_ID}
    ...    ${aws_bucket_name}=${S3_DEFAULT_BUCKET}    ${aws_secret_access}=${S3.AWS_SECRET_ACCESS_KEY}
    ...    ${aws_region}=${S3.AWS_DEFAULT_REGION}    ${aws_s3_endpoint}=${S3.AWS_DEFAULT_ENDPOINT}
    Wait Until Page Contains Element    ${S3_NAME_DC_INPUT_XP}
    Input Text    ${S3_NAME_DC_INPUT_XP}    ${dc_name}
    Input Text    ${S3_KEY_DC_INPUT_XP}    ${aws_access_key}
    Input Text    ${S3_SECRET_DC_INPUT_XP}    ${aws_secret_access}
    Input Text    ${S3_ENDPOINT_DC_INPUT_XP}    ${aws_s3_endpoint}
    Input Text    ${S3_REGION_DC_INPUT_XP}    ${aws_region}
    Input Text    ${S3_BUCKET_DC_INPUT_XP}    ${aws_bucket_name}

Verify Model Status
    [Documentation]    Checks the reported model status in the Model Serving or DS Project in the dashboard.
    ...    status can be "success" or any other string (which will expect failure status).
    [Arguments]    ${model_name}    ${expected_status}=success
    IF    "${expected_status}"=="success"
        Wait Until Keyword Succeeds    120s    5s
        ...    Page Should Contain Element    //div[.="${model_name} "]${MS_TABLE_STATUS}${MS_TABLE_STATUS_SUCCESS}
        Page Should Not Contain Element    //div[.="${model_name} "]${MS_TABLE_STATUS}${MS_TABLE_STATUS_FAILURE}
    ELSE
        Wait Until Keyword Succeeds    120s    5s
        ...    Page Should Contain Element    //div[.="${model_name} "]${MS_TABLE_STATUS}${MS_TABLE_STATUS_FAILURE}
        Page Should Not Contain Element    //div[.="${model_name} "]${MS_TABLE_STATUS}${MS_TABLE_STATUS_SUCCESS}
    END

Delete Model Via UI
    [Documentation]    Deletes a deployed model from the Model Serving page in the dashboard.
    [Arguments]    ${model_name}
    Page Should Contain Element    xpath://div[.="${model_name} "]
    Click Element    xpath://div[.="${model_name} "]${MS_TABLE_DROPDOWN_TOGGLE}
    Click Element    xpath://div[.="${model_name} "]${MS_TABLE_DROPDOWN_TOGGLE}/..//button[.="Delete"]
    Wait Until Page Contains Element    xpath://input[@id="delete-modal-input"]
    Input Text    xpath://input[@id="delete-modal-input"]    ${model_name}
    Click Button    Delete deployed model
    Wait Until Page Does Not Contain Element    xpath://div[.="${model_name} "]

Open Model Edit Modal
    [Documentation]    Opens the modal used to edit the details of an already deployed model.
    [Arguments]    ${model_name}
    Click Element    //div[.="${model_name} "]${MS_TABLE_DROPDOWN_TOGGLE}
    Click Element    //div[.="${model_name} "]${MS_TABLE_DROPDOWN_TOGGLE}/..//button[.="Edit"]
    Wait Until Page Contains    xpath://h1[.="Deploy model"]

Get Model Route via UI
    [Documentation]    Grabs the serving route (URL) of an already deployed model from the Model Serving page.
    [Arguments]    ${model_name}
    # TODO: Open model serving home page if needed?
    SeleniumLibrary.Page Should Contain Element    xpath://div[.="${model_name} "]
    ${route_xpath}=    Set Variable    xpath://div[.="${model_name} "]${MS_TABLE_ENDPOINT_INPUT}
    ${loaded}=    Run Keyword And Return Status    SeleniumLibrary.Wait Until Page Contains Element    ${route_xpath}    timeout=15s
    IF    ${loaded} == ${FALSE}
        Log    message=Model Route was not loaded in UI (RHOAIENG-1919). Trying refreshing!    level=WARN
        SeleniumLibrary.Reload Page
        SeleniumLibrary.Wait Until Page Contains Element    ${route_xpath}    timeout=15s
    END
    ${url}=    SeleniumLibrary.Get Element Attribute    ${route_xpath}    value
    RETURN    ${url}

Open ${section} Options Menu
    [Documentation]    Opens the "Options menu" dropdown for different sections
    ...    Valid sections are: "Name", "Model framework (name - version)", "Project"
    ${optionsmenu}=    Run Keyword And Return Status    Page Should Contain Element
    ...    xpath://span[.="${section}"]/../../..//button[@aria-label="Options menu"]
    IF    ${optionsmenu} == ${TRUE}
        SeleniumLibrary.Click Element    xpath://span[.="${section}"]/../../..//button[@aria-label="Options menu"]  # Remove attribute which is not present anymore
    ELSE
        SeleniumLibrary.Click Element    xpath://span[.="${section}"]/../../..//button  # Remove attribute which is not present anymore
    END

Get Access Token via UI
    [Documentation]    Returns the access token for models deployed in a specific project
    ...    by using the UI of DSP
    [Arguments]    ${project_name}    ${service_account_name}=default-name
    Open Data Science Project Details Page    ${project_name}
    ${token}=    Get Model Serving Access Token via UI    ${service_account_name}
    RETURN    ${token}

Get Model Project
    [Documentation]    Returns the project under which a model has been deployed
    [Arguments]    ${model_name}
    Page Should Contain Element    //div[.="${model_name} "]
    ${project_name}=    Get Text    xpath://div[.="${model_name} "]${MS_TABLE_PROJECT}
    ${tmp_list}=    Text To List    ${project_name}
    ${project_name}=    Set Variable    ${tmp_list}[0]
    RETURN    ${project_name}

Get Model Inference
    [Documentation]    Returns the inference result after sending a POST request to a deployed
    ...    model endpoint. If token authentication is needed for the model, ${token_auth} should be
    ...    set to ${TRUE}.
    [Arguments]    ${model_name}    ${inference_input}    ${token_auth}=${FALSE}
    ...    ${project_title}=${NONE}
    ${self_managed} =    Is RHODS Self-Managed
    ${url}=    Get Model Route via UI    ${model_name}
    ${curl_cmd}=     Set Variable    curl -s ${url} -d ${inference_input}
    IF    ${token_auth}
        IF    "${project_title}" == "${NONE}"
            ${project_title}=    Get Model Project    ${model_name}
        END
        ${token}=    Get Access Token via UI    ${project_title}
        ${curl_cmd}=     Catenate    ${curl_cmd}    -H "Authorization: Bearer ${token}"
    END
    IF  ${self_managed}==${TRUE}
        Fetch Openshift CA Bundle
        ${curl_cmd}=     Catenate    ${curl_cmd}    --cacert openshift_ca.crt
    END
    ${inference_output} =    Run    ${curl_cmd}
    RETURN    ${inference_output}

Verify Model Inference
    [Documentation]    Verifies that the inference result of a model is equal to an expected output
    [Arguments]    ${model_name}    ${inference_input}    ${expected_inference_output}    ${token_auth}=${FALSE}
    ...    ${project_title}=${NONE}
    ${inference_output} =    Get Model Inference    ${model_name}    ${inference_input}    ${token_auth}
    ...    project_title=${project_title}
    ${result}    ${list} =    Inference Comparison    ${expected_inference_output}    ${inference_output}
    Log    ${result}
    Log    ${list}
    IF    ${result}==False
        Fail    msg=comparison between expected and actual failed, ${list}
    END

Clean Up Model Serving Page
    [Documentation]    Deletes all currently deployed models, if any are present.
    # Returns an empty list if no matching elements found
    ${models} =    Get WebElements    xpath://table/tbody/tr/td[@data-label="Name"]/div/a
    FOR  ${model}  IN  @{models}
        ${name} =    Get Text   ${model}
        Delete Model Via UI    ${name}
    END

Add Namespace To ServiceMeshMemberRoll
    [Arguments]    ${namespace}    ${servicemesh_ns}=istio-system
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc patch smmr/default -n ${servicemesh_ns} --type='json' -p="[{'op': 'add', 'path': '/spec/members/-', 'value': \"${namespace}\"}]"
    Should Be Equal As Integers    ${rc}    ${0}

Namespace Should Be Removed From ServiceMeshMemberRoll
    [Documentation]    Checks if the given namespace is present in the SMMR.
    ...                If yes, it fails
    [Arguments]    ${namespace}    ${servicemesh_ns}=istio-system
    ${rc}    ${member_list}=    Run And Return Rc And Output
    ...    oc get smmr/default -n ${servicemesh_ns} -o json | jq '.spec.members'
    Should Be Equal As Integers    ${rc}    ${0}
    IF    $member_list == "null"
        Log    message=ServiceMeshMemberRoll already cleaned up
    ELSE
        ${rc}    ${ns_idx}=    Run And Return Rc And Output
        ...    oc get smmr/default -n ${servicemesh_ns} -o json | jq '.spec.members | map(. == "${namespace}") | index(true)'    # robocop: disable
        Should Be Equal As Integers    ${rc}    ${0}
        Should Be Equal As Strings    ${ns_idx}    null
        ...    msg=${namespace} should have been automatically removed from SMMR
    END


Deploy Model Via CLI
    [Documentation]    Deploys a model using Model Serving feature by applying the InfereceService
    ...                yaml via CLI. It assumes that the necessary Runtime has been already created
    ...                in the same ${namespace}
    [Arguments]    ${isvc_filepath}    ${namespace}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc apply -f ${isvc_filepath} -n ${namespace}
    Should Be Equal As Integers    ${rc}    ${0}
    Should Not Be Empty    ${out}

Deploy Kserve Model Via UI  #robocop: disable
    [Documentation]  Deploys a model using the kserve/caikit runtime using the Data Science Projects UI
    [Arguments]    ${model_name}    ${serving_runtime}    ${data_connection}    ${path}
    ...    ${model_framework}=caikit    ${replicas}=1    ${size}=Small    ${no_gpus}=${0}
    ${first_deploy}=    Run Keyword And Return Status
    ...    Page Should Contain Element    xpath=//article[@id="single-serving-platform-card"]
    IF  ${first_deploy}
        Click Button    //article[@id="single-serving-platform-card"]//button[.="Deploy model"]
    ELSE
        Click Button    //div[@id="model-server"]//button[.="Deploy model"]
    END
    Wait Until Page Contains Element    xpath=${KSERVE_MODAL_HEADER}
    Set Model Name   ${model_name}
    Select Kserve Serving Runtime    ${serving_runtime}
    Select Framework    ${model_framework}
    Set Replicas Number With Buttons    ${replicas}
    Set Server Size    ${size}
    Select Existing Data Connection    ${data_connection}
    Set Folder Path    ${path}
    IF    ${no_gpus} > ${0}
        ${gpu_enabled}=    Run Keyword And Return Status    Verify GPU Selector Is Usable
        IF    ${gpu_enabled}==False
            Log    GPU requested but not available
            Fail
        END
        Set Accelerator
        Set Number of GPU With Buttons   ${no_gpus}
    END
    Click Button    Deploy
    Wait Until Page Does Not Contain Element    xpath=${KSERVE_MODAL_HEADER}   timeout=60s

Select Kserve Serving Runtime
    [Documentation]    Opens the Runtime dropdown in the deploy modal for kserve models and select the given runtime
    [Arguments]    ${runtime}=Caikit
    Page Should Contain Element    ${KSERVE_RUNTIME_DROPDOWN}
    Click Element    ${KSERVE_RUNTIME_DROPDOWN}/button
    Click Element    ${KSERVE_RUNTIME_DROPDOWN}/ul//span[contains(text(),"${runtime}")]

Get Kserve Inference Host Via UI
    [Documentation]    Fetches the host of the model's URL from the Data Science Project UI
    [Arguments]    ${model_name}    ${retries}=1
    FOR  ${retry_idx}  IN RANGE  0  1+${retries}
        Wait Until Page Contains Element    //td[@data-label="Name"]/div[.="${model_name} "]/../..//td[@data-label="Inference endpoint"]    timeout=30s  #robocop: disable
        Wait Until Page Contains Element    //td[@data-label="Name"]/div[.="${model_name} "]/../..//td[@data-label="Status"]//span[@aria-label="success icon"]
        ...  timeout=30s  #robocop: disable
        ${endpoint} =    Get Element Attribute    //td[@data-label="Name"]/div[.="${model_name} "]/../..//td[@data-label="Inference endpoint"]//input    value  #robocop: disable
        IF  "${endpoint}"!="${EMPTY}"
            RETURN    ${endpoint}
        END
        Reload Page
    END
    Log    Failed to get model serving host through the UI
    Take Screenshot

Enable Model Serving Runtime Using CLI
    [Documentation]  Update OdhDashboardConfig to enable the model runtime
    [Arguments]    ${namespace}    ${name}=${EMPTY}
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc patch OdhDashboardConfig odh-dashboard-config --type=json -p '[{op: "replace", path: "/spec/templateDisablement", value: [${name}]}]' -n ${namespace}
    Should Be Equal As Integers    ${rc}         ${0}

Disable Model Serving Runtime Using CLI
    [Documentation]  Update OdhDashboardConfig to disable the model runtime
    [Arguments]    ${namespace}    ${name}=ovms-gpu
    ${rc}    ${out}=    Run And Return Rc And Output
    ...    oc patch OdhDashboardConfig odh-dashboard-config --type=json -p '[{op: "replace", path: "/spec/templateDisablement", value: ["${name}"]}]' -n ${namespace}
    Should Be Equal As Integers    ${rc}         ${0}

Wait Until Runtime Pod Is Running
    [Arguments]    ${server_name}    ${project_title}    ${timeout}=10s
    ${ns_name}=    Get Openshift Namespace From Data Science Project   project_title=${project_title}
    ${runtime_pod_name} =    Replace String Using Regexp    string=${server_name}    pattern=\\s    replace_with=-
    ${runtime_pod_name} =    Convert To Lower Case    ${runtime_pod_name}
    Log    name=modelmeshserving${runtime_pod_name}
    Wait For Pods To Be Ready    label_selector=name=modelmesh-serving-${runtime_pod_name}
    ...    namespace=${ns_name}    timeout=${timeout}

Create Custom Serving Runtime Using Template By CLI
    [Documentation]  Use Openshift API to create a custome runtime using template CR
    [Arguments]      ${file_path}
    ${return_code}    ${output}    Run And Return Rc And Output   oc apply -f ${file_path} -n ${APPLICATIONS_NAMESPACE}
    Log To Console    ${output}
    Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file

Get Model Runtime Template Resource Name By Runtime Name OR Display Name
    [Documentation]  Get template name based on runtime name or Display name
    [Arguments]      ${runtime_name}=${EMPTY}     ${runtime_display_name}=${EMPTY}
    IF    "${runtime_name}" != ""
          ${return_code}    ${output}    Run And Return Rc And Output   oc get templates -ojson -n ${APPLICATIONS_NAMESPACE} | jq '.items[] | select(.objects[].metadata."name"=="${runtime_name}") | .metadata.name' | tr -d '"'   #robocop:disable
          Log To Console    ${output}
          Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file
          RETURN   ${output}
    ELSE IF   "${runtime_display_name}" != ""
          ${return_code}    ${output}    Run And Return Rc And Output   oc get templates -ojson -n ${APPLICATIONS_NAMESPACE} | jq '.items[] | select(.objects[].metadata.annotations."openshift.io/display-name"=="${runtime_display_name}") | .metadata.name' | tr -d '"'   #robocop:disable
          Log To Console    ${output}
          Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file
          RETURN   ${output}
    ELSE IF   "${runtime_name}" == "" and "${runtime_display_name}" == ""
         Fail     msg=Kindly provide runtime name or display name
    END

Delete Serving Runtime Template From CLI By Runtime Name OR Display Name
    [Documentation]  Delete template name based on runtime name or Display name
    [Arguments]      ${runtime_name}=${EMPTY}     ${runtime_display_name}=${EMPTY}
    IF    "${runtime_name}" != ""
          ${template_name}   Get Model Runtime Template Resource Name By Runtime Name OR Display Name  runtime_name=${runtime_name}
          ${return_code}    ${output}    Run And Return Rc And Output   oc delete templates ${template_name} -n ${APPLICATIONS_NAMESPACE}  #robocop:disable
          Log To Console    ${output}
          Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file
    ELSE IF   "${runtime_display_name}" != ""
          ${template_name}   Get Model Runtime Template Resource Name By Runtime Name OR Display Name  runtime_display_name=${runtime_display_name}
          ${return_code}    ${output}    Run And Return Rc And Output   oc delete templates ${template_name} -n ${APPLICATIONS_NAMESPACE}  #robocop:disable
          Log To Console    ${output}
          Should Be Equal As Integers    ${return_code}     0   msg=Error while applying the provided file
    ELSE IF   "${runtime_name}" == "" and "${runtime_display_name}" == ""
         Fail     msg=Kindly provide runtime name or display name
    END

Clean Up DSP Page
    [Documentation]    Removes all DSP Projects, if any are present
    ${modal} =    Run Keyword And Return Status    Page Should Contain Element    xpath=${KSERVE_MODAL_HEADER}
    IF  ${modal}==${TRUE}
        Click Element    //button[@aria-label="Close"]
    END
    Open Data Science Projects Home Page
    WHILE    ${TRUE}
        ${projects}=    Get All Displayed Projects
        IF    len(${projects})==0
            BREAK
        END
        Delete Data Science Projects From CLI    ${projects}
        Reload Page
        Wait Until Page Contains    Data science projects
    END

Try Opening Create Server
    [Documentation]    Tries to clean up DSP and Model Serving pages
    ...    In order to deploy a single model in a new project. ${retries}
    ...    controls how many retries are made.
    [Arguments]    ${retries}=3
    FOR    ${try}    IN RANGE    0    ${retries}
        ${status}=    Run Keyword And Return Status    Page Should Contain    Select a project
        IF    ${status}
            Click Button    Select a project
            RETURN
        ELSE
            Clean Up Model Serving Page
            Clean Up DSP Page
            Open Model Serving Home Page
            Reload Page
            Sleep  5s
        END
    END

Set Up Project
    [Documentation]    Creates the DS Project (if not exists), creates the data connection for the models,
    ...                creates caikit runtime. This can be used as test setup
    [Arguments]    ${namespace}    ${single_prj}=${TRUE}    ${enable_metrics}=${FALSE}    ${dc_name}=kserve-connection
    Open Model Serving Home Page
    IF    ${single_prj}
        Try Opening Create Server
        Wait for RHODS Dashboard to Load    wait_for_cards=${FALSE}    expected_page=Data Science Projects
    ELSE
        Open Data Science Projects Home Page
        Wait for RHODS Dashboard to Load    wait_for_cards=${FALSE}    expected_page=Data Science Projects
    END
    Create Data Science Project    title=${namespace}    description=kserve test project
    Create S3 Data Connection    project_title=${namespace}    dc_name=${dc_name}
    ...            aws_access_key=${S3.AWS_ACCESS_KEY_ID}    aws_secret_access=${S3.AWS_SECRET_ACCESS_KEY}
    ...            aws_bucket_name=${S3.BUCKET_3.NAME}    aws_s3_endpoint=${S3.BUCKET_3.ENDPOINT}
    ...            aws_region=${S3.BUCKET_3.REGION}
    IF   ${enable_metrics}
        Oc Apply    kind=ConfigMap    src=${UWM_ENABLE_FILEPATH}
        Oc Apply    kind=ConfigMap    src=${UWM_CONFIG_FILEPATH}
    ELSE
        Log    message=Skipping UserWorkloadMonitoring enablement.
    END