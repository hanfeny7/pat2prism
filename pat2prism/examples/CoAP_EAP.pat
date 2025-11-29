# Example PAT-like CoAP-EAP fragment (simplified)

channel ComSC 0;
channel ComCA 0;

SmartObject() =
    ComSC!CoAP_POST ->
    ComSC?CoAP_ACK.N_C ->
    ComSC?EAP_Request_Identity ->
    ComSC!EAP_Response_Identity.ID_P ->
    ComSC?EAP_Request_PSK_M1.N_S.ID_S ->
    ComSC!EAP_Response_PSK_M2.MAC_P ->
    ComSC?EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    ComSC!EAP_Response_PSK_M4 ->
    ComSC?EAP_Success.MSK ->
    Skip();

Controller() =
    ComSC?CoAP_POST ->
    ComSC!CoAP_ACK.N_C ->
    ComSC?CoAP_ACK.N_P ->
    ComSC!EAP_Request_Identity ->
    ComSC?EAP_Response_Identity.ID_P ->
    ComCA!EAP_Response_Identity.ID_P ->
    ComCA?EAP_Request_PSK_M1.N_S.ID_S ->
    ComSC!EAP_Request_PSK_M1.N_S.ID_S ->
    ComSC?EAP_Response_PSK_M2.MAC_P ->
    ComCA!EAP_Response_PSK_M2.MAC_P ->
    ComCA?EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    ComSC!EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    ComSC?EAP_Response_PSK_M4 ->
    ComCA!EAP_Response_PSK_M4 ->
    ComCA?EAP_Success.MSK ->
    ComSC!EAP_Success ->
    Skip();

AAA_Server() =
    ComCA?EAP_Response_Identity.ID_P ->
    ComCA!EAP_Request_PSK_M1.N_S.ID_S ->
    ComCA?EAP_Response_PSK_M2.MAC_P ->
    ComCA!EAP_Request_PSK_M3.MAC_S.PCHANNEL ->
    ComCA?EAP_Response_PSK_M4 ->
    ComCA!EAP_Success.MSK ->
    Skip();

System() = SmartObject() || Controller() || AAA_Server();
