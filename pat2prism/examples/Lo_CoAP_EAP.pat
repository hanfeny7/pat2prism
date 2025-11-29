channel ComSC 0;
channel ComCA 0;

// EAP message types
enum EAP_TYPES { EAP_Request_PSK_M1, EAP_Response_PSK_M2, EAP_Request_PSK_M3, EAP_Response_PSK_M4, EAP_Success, LO_CoAP_POST, Final_CoAP_POST, CoAP_ACK };

// Constants and state variables
var PSK = 1234;
var ID_P = 1;
var ID_S = 2;

var auth_complete_SO = false;
var auth_complete_Controller = false;
var auth_complete_AAA = false;
var MAC_P_valid = false;
var MAC_S_valid = false;
var AUTH_valid = false;

var random_var = [101, 1011, 1001, 1101];
var N_C = 0;
var N_P = 0;
var N_S = 0;
var AK = 0;
var MSK = 0;
var EMSK = 0;
var MAC_P = 0;
var MAC_S = 0;
var PCHANNEL = 0;
var AUTH = 0;
var expected_AUTH = 0;

// Simplified SmartObject process
SmartObject() =
    call(Generate_N_P, 0) ->
    ComSC!LO_CoAP_POST.ID_P.N_P ->
    ComSC?EAP_Request_PSK_M1.N_S.ID_S ->
    call(Compute_AK, PSK, N_S, N_P) ->
    call(Compute_MAC_P, AK, ID_P, ID_S, N_S, N_P) ->
    ComSC!EAP_Response_PSK_M2.MAC_P ->
    ComSC?EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    call(Verify_MAC_S, MAC_S) ->
    if (MAC_S_valid == true) { 
        ComSC!EAP_Response_PSK_M4 ->
        ComSC?Final_CoAP_POST.N_C.AUTH ->
        call(Verify_AUTH, AUTH) ->
        if (AUTH_valid == true) { 
            ComSC!CoAP_ACK ->
            call(Derive_MSK_EMSK, PSK, N_S, N_P, N_C) ->
            auth_complete_SO = true ->
            Skip()
        } else { skip -> SmartObject() }
    } else { skip -> SmartObject() };

// Simplified Controller process
Controller() =
    ComSC?LO_CoAP_POST.ID_P.N_P ->
    ComCA!LO_CoAP_POST.ID_P.N_P ->
    ComCA?EAP_Request_PSK_M1.N_S.ID_S ->
    ComSC!EAP_Request_PSK_M1.N_S.ID_S ->
    ComSC?EAP_Response_PSK_M2.MAC_P ->
    ComCA!EAP_Response_PSK_M2.MAC_P ->
    ComCA?EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    ComSC!EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    ComSC?EAP_Response_PSK_M4 ->
    ComCA!EAP_Response_PSK_M4 ->
    ComCA?EAP_Success.MSK ->
    call(Generate_N_C, 1) ->
    call(Compute_AUTH, MSK, N_C) ->
    ComSC!Final_CoAP_POST.N_C.AUTH ->
    ComSC?CoAP_ACK ->
    auth_complete_Controller = true ->
    Controller();

// Simplified AAA server process
AAA_Server() =
    ComCA?LO_CoAP_POST.ID_P.N_P ->
    call(Generate_N_S, 2) ->
    ComCA!EAP_Request_PSK_M1.N_S.ID_S ->
    ComCA?EAP_Response_PSK_M2.MAC_P ->
    call(Compute_AK, PSK, N_S, N_P) ->
    call(Compute_MAC_P, AK, ID_P, ID_S, N_S, N_P) ->
    call(Verify_MAC_P, MAC_P) ->
    if (MAC_P_valid == true) {
        call(Compute_MAC_S, AK, ID_S, ID_P, N_P, N_S) ->
        ComCA!EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
        ComCA?EAP_Response_PSK_M4 ->
        call(Derive_MSK_EMSK, PSK, N_S, N_P, 0) ->
        ComCA!EAP_Success.MSK ->
        auth_complete_AAA = true ->
        Skip()
    } else { skip -> AAA_Server() };

System() = SmartObject() || Controller() || AAA_Server();
assert System() ;
