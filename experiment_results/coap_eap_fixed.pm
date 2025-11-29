// coap_eap_fixed.pm
// Fixed MDP model for CoAP-EAP
// Based on user provided singlefile model, fixed for PRISM syntax and logic

mdp

// ===== Parameters =====
const double p_flip = 0.0;     // probability of bit-flip corruption
const double p_loss = 0.0;     // probability of message loss
const int MAX_MSG = 10;         // message id upper bound
const bool active_intruder;     // Switch to enable/disable active intruder attacks
const int NO_MSG = 0;
const int CORRUPT = 10;

// ===== Message Encoding =====
// 0 -> NO_MSG
// 1 -> CoAP_ACK
// 2 -> CoAP_POST
// 3 -> EAP_Request_Identity
// 4 -> EAP_Request_PSK_M1
// 5 -> EAP_Request_PSK_M3
// 6 -> EAP_Response_Identity
// 7 -> EAP_Response_PSK_M2
// 8 -> EAP_Response_PSK_M4
// 9 -> EAP_Success
// 10 -> CORRUPT

// ===== Global Channel & Buffers =====
global chan_ComSC : [0..MAX_MSG] init NO_MSG;    // channel SmartObject <-> Controller
global chan_ComCA : [0..MAX_MSG] init NO_MSG;    // channel Controller <-> AAA
global out_sc    : [0..MAX_MSG] init NO_MSG;    // sender-side output buffer for SC
global out_ca    : [0..MAX_MSG] init NO_MSG;    // sender-side output buffer for CA

// Session/auth tracking
global auth_complete_SO : bool init false;
global auth_complete_Controller : bool init false;
global auth_complete_AAA : bool init false;
global session_key_SO : [0..2] init 0;    // 0 = none, 1 = derived, 2 = compromised
global session_key_AAA : [0..2] init 0;   // 0 = none, 1 = derived, 2 = compromised

// Intruder observables/flags
global intr_buf_sc : [0..MAX_MSG] init NO_MSG;  // intruder cache for SC-direction
global intr_buf_ca : [0..MAX_MSG] init NO_MSG;  // intruder cache for CA-direction
global intr_knows_msk : bool init false;        // intruder learned MSK
global replay_detected : bool init false;
global integrity_violation : bool init false;
global mitm_detected : bool init false;
global dos_detected : bool init false;

// small identifiers (abstract)
const int ID_P = 1;
const int ID_S = 2;
const int PSK = 1234;

// ===== Module: SmartObject (device) =====
module SmartObject
  so : [0..12] init 0;

  // 0: initially send CoAP_POST
  [] so=0 & out_sc=NO_MSG -> (out_sc' = 2) & (so' = 1);

  // 1: wait until controller ack appears
  [] so=1 & chan_ComSC=1 -> (chan_ComSC' = NO_MSG) & (so' = 2);

  // 2: send CoAP_ACK back
  [] so=2 & out_sc=NO_MSG -> (out_sc' = 1) & (so' = 3);

  // 3: wait for EAP_Request_Identity
  [] so=3 & chan_ComSC=3 -> (chan_ComSC' = NO_MSG) & (so' = 4);

  // 4: send EAP_Response_Identity
  [] so=4 & out_sc=NO_MSG -> (out_sc' = 6) & (so' = 5);

  // 5: wait for PSK_M1
  [] so=5 & chan_ComSC=4 -> (chan_ComSC' = NO_MSG) & (so' = 6);

  // 6: send PSK_M2
  [] so=6 & out_sc=NO_MSG -> (out_sc' = 7) & (so' = 7);

  // 7: wait for PSK_M3
  [] so=7 & chan_ComSC=5 -> (chan_ComSC' = NO_MSG) & (so' = 8);

  // 8: send PSK_M4
  [] so=8 & out_sc=NO_MSG -> (out_sc' = 8) & (so' = 9);

  // 9: wait for EAP_Success
  [] so=9 & chan_ComSC=9 -> (chan_ComSC' = NO_MSG) & (session_key_SO' = 1) & (so' = 10);

  // 10: mark auth complete
  [] so=10 -> (auth_complete_SO' = true) & (so' = 11);

  // final sink state
  [] so=11 -> (so' = 11);

  // Error handling: Drop unexpected messages to avoid deadlock
  [] so=1 & chan_ComSC!=1 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 1);
  [] so=3 & chan_ComSC!=3 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 3);
  [] so=5 & chan_ComSC!=4 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 5);
  [] so=7 & chan_ComSC!=5 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 7);
  [] so=9 & chan_ComSC!=9 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 9);
endmodule

// ===== Module: Controller (CoAP server / EAP proxy) =====
module Controller
  c : [0..20] init 0;

  // 0: wait for CoAP_POST
  [] c=0 & chan_ComSC=2 -> (chan_ComSC' = NO_MSG) & (c' = 1);

  // 1: send CoAP_ACK
  [] c=1 & out_sc=NO_MSG -> (out_sc' = 1) & (c' = 2);

  // 2: wait for device's ack
  [] c=2 & chan_ComSC=1 -> (chan_ComSC' = NO_MSG) & (c' = 3);

  // 3: start EAP identity exchange
  [] c=3 & out_sc=NO_MSG -> (out_sc' = 3) & (c' = 4);

  // 4: receive EAP_Response_Identity
  [] c=4 & chan_ComSC=6 -> (chan_ComSC' = NO_MSG) & (c' = 5);

  // 5: forward identity to AAA
  [] c=5 & out_ca=NO_MSG -> (out_ca' = 6) & (c' = 6);

  // 6: wait for PSK_M1 from AAA
  [] c=6 & chan_ComCA=4 -> (chan_ComCA' = NO_MSG) & (c' = 7);

  // 7: forward PSK_M1 to SO
  [] c=7 & out_sc=NO_MSG -> (out_sc' = 4) & (c' = 8);

  // 8: wait for PSK_M2 from SO
  [] c=8 & chan_ComSC=7 -> (chan_ComSC' = NO_MSG) & (c' = 9);

  // 9: forward PSK_M2 to AAA
  [] c=9 & out_ca=NO_MSG -> (out_ca' = 7) & (c' = 10);

  // 10: wait for PSK_M3 from AAA
  [] c=10 & chan_ComCA=5 -> (chan_ComCA' = NO_MSG) & (c' = 11);

  // 11: forward PSK_M3 to SO
  [] c=11 & out_sc=NO_MSG -> (out_sc' = 5) & (c' = 12);

  // 12: wait for PSK_M4 from SO
  [] c=12 & chan_ComSC=8 -> (chan_ComSC' = NO_MSG) & (c' = 13);

  // 13: forward PSK_M4 to AAA
  [] c=13 & out_ca=NO_MSG -> (out_ca' = 8) & (c' = 14);

  // 14: wait for EAP_Success from AAA
  [] c=14 & chan_ComCA=9 -> (chan_ComCA' = NO_MSG) & (c' = 15);

  // 15: forward EAP_Success to SO
  [] c=15 & out_sc=NO_MSG -> (out_sc' = 9) & (c' = 16);

  // 16: mark auth complete
  [] c=16 -> (auth_complete_Controller' = true) & (c' = 17);

  // final sink
  [] c=17 -> (c' = 17);

  // Error handling
  [] c=0 & chan_ComSC!=2 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 0);
  [] c=2 & chan_ComSC!=1 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 2);
  [] c=4 & chan_ComSC!=6 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 4);
  [] c=6 & chan_ComCA!=4 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (c' = 6);
  [] c=8 & chan_ComSC!=7 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 8);
  [] c=10 & chan_ComCA!=5 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (c' = 10);
  [] c=12 & chan_ComSC!=8 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 12);
  [] c=14 & chan_ComCA!=9 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (c' = 14);
endmodule

// ===== Module: AAA Server =====
module AAA_Server
  a : [0..10] init 0;

  // 0: receive identity from Controller
  [] a=0 & chan_ComCA=6 -> (chan_ComCA' = NO_MSG) & (a' = 1);

  // 1: send PSK_M1
  [] a=1 & out_ca=NO_MSG -> (out_ca' = 4) & (a' = 2);

  // 2: wait for PSK_M2
  [] a=2 & chan_ComCA=7 -> (chan_ComCA' = NO_MSG) & (a' = 3);

  // 3: send PSK_M3
  [] a=3 & out_ca=NO_MSG -> (out_ca' = 5) & (a' = 4);

  // 4: wait for PSK_M4
  [] a=4 & chan_ComCA=8 -> (chan_ComCA' = NO_MSG) & (a' = 5);

  // 5: send EAP_Success
  [] a=5 & out_ca=NO_MSG -> (out_ca' = 9) & (session_key_AAA' = 1) & (a' = 6);

  // 6: mark auth complete
  [] a=6 -> (auth_complete_AAA' = true) & (a' = 7);

  [] a=7 -> (a' = 7);

  // Error handling
  [] a=0 & chan_ComCA!=6 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (a' = 0);
  [] a=2 & chan_ComCA!=7 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (a' = 2);
  [] a=4 & chan_ComCA!=8 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (a' = 4);
endmodule

// ===== Module: Channel Processing (SC) =====
module Channel_SC
  cs : [0..2] init 0;
  // 0: idle; 1: message in channel
  
  // Move emitted message into channel with probabilistic loss
  [] out_sc!=NO_MSG & chan_ComSC=NO_MSG -> 
      p_loss : (out_sc' = NO_MSG) // lost
    + (1 - p_loss) : (chan_ComSC' = out_sc) & (out_sc' = NO_MSG) & (cs' = 1);

  // When a message is present, model probabilistic bit-flip corruption
  [] cs=1 & chan_ComSC!=NO_MSG ->
       p_flip : (chan_ComSC' = CORRUPT) & (integrity_violation' = true) & (cs' = 1)
     + (1 - p_flip) : (cs' = 1);

  // No-op receive progress (receiver modules will read and clear chan_ComSC)
  [] cs=1 & chan_ComSC=NO_MSG -> (cs' = 0);
endmodule

// ===== Module: Channel Processing (CA) =====
module Channel_CA
  ca : [0..2] init 0;

  [] out_ca!=NO_MSG & chan_ComCA=NO_MSG -> 
      p_loss : (out_ca' = NO_MSG) // lost
    + (1 - p_loss) : (chan_ComCA' = out_ca) & (out_ca' = NO_MSG) & (ca' = 1);

  [] ca=1 & chan_ComCA!=NO_MSG ->
       p_flip : (chan_ComCA' = CORRUPT) & (integrity_violation' = true) & (ca' = 1)
     + (1 - p_flip) : (ca' = 1);

  [] ca=1 & chan_ComCA=NO_MSG -> (ca' = 0);
endmodule

// ===== Module: Intruder =====
module Intruder
  i : [0..6] init 0;

  // Intercept SC-direction emission
  // If active_intruder is false, we only allow passing (implicit) or very limited actions
  // Here we guard all attack transitions with active_intruder=true

  [] out_sc!=NO_MSG & chan_ComSC=NO_MSG & active_intruder=true -> (intr_buf_sc' = out_sc) & (out_sc' = NO_MSG) & (mitm_detected' = true) & (i' = 1);

  // Intercept CA-direction emission
  [] out_ca!=NO_MSG & chan_ComCA=NO_MSG & active_intruder=true -> (intr_buf_ca' = out_ca) & (out_ca' = NO_MSG) & (mitm_detected' = true) & (i' = 1);

  // Replay / inject SC-direction
  [] intr_buf_sc!=NO_MSG & chan_ComSC=NO_MSG & active_intruder=true -> (chan_ComSC' = intr_buf_sc) & (intr_buf_sc' = NO_MSG) & (replay_detected' = true) & (i' = 2);
  [] intr_buf_sc!=NO_MSG & chan_ComSC=NO_MSG & active_intruder=true -> (chan_ComSC' = 4) & (intr_buf_sc' = NO_MSG) & (i' = 3); // forge PSK_M1

  // Replay / inject CA-direction
  [] intr_buf_ca!=NO_MSG & chan_ComCA=NO_MSG & active_intruder=true -> (chan_ComCA' = intr_buf_ca) & (intr_buf_ca' = NO_MSG) & (replay_detected' = true) & (i' = 2);
  [] intr_buf_ca!=NO_MSG & chan_ComCA=NO_MSG & active_intruder=true -> (chan_ComCA' = 7) & (intr_buf_ca' = NO_MSG) & (i' = 3); // forge PSK_M2

  // Intruder learns MSK (Passive monitoring is always on)
  [] intr_buf_sc=9 -> (intr_knows_msk' = true) & (intr_buf_sc' = NO_MSG);
  [] intr_buf_ca=9 -> (intr_knows_msk' = true) & (intr_buf_ca' = NO_MSG);

  // Forge-inject at any time when channel free
  [] chan_ComSC=NO_MSG & active_intruder=true -> (chan_ComSC' = 7) & (i' = 4); // forge PSK_M2
  [] chan_ComCA=NO_MSG & active_intruder=true -> (chan_ComCA' = 4) & (i' = 4); // forge PSK_M1

  // Simple DOS attempt
  [] out_sc!=NO_MSG & active_intruder=true -> (out_sc' = NO_MSG) & (dos_detected' = true) & (i' = 5);
  [] out_ca!=NO_MSG & active_intruder=true -> (out_ca' = NO_MSG) & (dos_detected' = true) & (i' = 5);

  // Reset Intruder state to allow repeated actions
  [] i!=0 -> (i' = 0);

endmodule

// ===== Labels for properties =====
label "auth_success" = (auth_complete_SO = true & auth_complete_AAA = true);
label "auth_partial" = (auth_complete_SO = true | auth_complete_AAA = true | auth_complete_Controller = true);
label "intruder_knows_msk" = (intr_knows_msk = true);
label "replay_detected" = (replay_detected = true);
label "integrity_violation" = (integrity_violation = true);
label "mitm_detected" = (mitm_detected = true);
label "dos_detected" = (dos_detected = true);
label "key_mismatch" = (session_key_SO != session_key_AAA) & (session_key_SO != 0) & (session_key_AAA != 0);

// ===== Rewards =====
rewards "msgs"
  chan_ComSC!=NO_MSG : 1;
  chan_ComCA!=NO_MSG : 1;
endrewards

rewards "bytes"
  chan_ComSC=2 : 140;  // CoAP POST
  chan_ComSC=1 : 80;   // CoAP ACK
  chan_ComSC=3 : 40;   // EAP Req Identity
  chan_ComSC=6 : 60;   // EAP Resp Identity
  chan_ComSC=4 : 120;  // PSK_M1
  chan_ComSC=7 : 100;  // PSK_M2
  chan_ComSC=5 : 120;  // PSK_M3
  chan_ComSC=8 : 100;  // PSK_M4
  chan_ComSC=9 : 160;  // EAP Success
endrewards
