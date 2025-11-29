// lo_coap_eap_fixed.pm
// Fixed MDP model for LO-CoAP-EAP
// Based on user provided singlefile model, fixed for PRISM syntax and logic

mdp

// ===== Parameters =====
const double p_flip = 0.0;     // bit-flip corruption prob
const double p_loss = 0.0;     // message loss prob
const int MAX_MSG = 10;
const bool active_intruder;     // Switch to enable/disable active intruder attacks
const int NO_MSG = 0;
const int CORRUPT = 10;

// ===== Message Encoding =====
// 0 -> NO_MSG
// 1 -> CoAP_ACK
// 2 -> EAP_Request_PSK_M1
// 3 -> EAP_Request_PSK_M3
// 4 -> EAP_Response_PSK_M2
// 5 -> EAP_Response_PSK_M4
// 6 -> EAP_Success
// 7 -> Final_CoAP_POST
// 8 -> LO_CoAP_POST
// 10 -> CORRUPT

// ===== Global Channel & Buffers =====
global chan_ComSC : [0..MAX_MSG] init NO_MSG;    // SO <-> Controller channel
global chan_ComCA : [0..MAX_MSG] init NO_MSG;    // Controller <-> AAA channel
global out_sc    : [0..MAX_MSG] init NO_MSG;    // sender buffer for SC
global out_ca    : [0..MAX_MSG] init NO_MSG;    // sender buffer for CA

// Session/auth tracking
global auth_complete_SO : bool init false;
global auth_complete_Controller : bool init false;
global auth_complete_AAA : bool init false;
global session_key_SO : [0..2] init 0;    // 0 = none, 1 = derived, 2 = compromised
global session_key_AAA : [0..2] init 0;

// Intruder observables/flags
global intr_buf_sc : [0..MAX_MSG] init NO_MSG;
global intr_buf_ca : [0..MAX_MSG] init NO_MSG;
global intr_knows_msk : bool init false;
global replay_detected : bool init false;
global integrity_violation : bool init false;
global mitm_detected : bool init false;
global dos_detected : bool init false;

// abstract ids / keys
const int ID_P = 1;
const int ID_S = 2;
const int PSK = 1234;

// ===== Module: SmartObject (device) =====
module SmartObject
  so : [0..12] init 0;

  // 0: send LO_CoAP_POST to controller
  [] so=0 & out_sc=NO_MSG -> (out_sc' = 8) & (so' = 1);

  // 1: wait for PSK_M1 (Controller forwards AAA's M1)
  [] so=1 & chan_ComSC=2 -> (chan_ComSC' = NO_MSG) & (so' = 2);

  // 2: send PSK_M2
  [] so=2 & out_sc=NO_MSG -> (out_sc' = 4) & (so' = 3);

  // 3: wait for PSK_M3
  [] so=3 & chan_ComSC=3 -> (chan_ComSC' = NO_MSG) & (so' = 4);

  // 4: send PSK_M4
  [] so=4 & out_sc=NO_MSG -> (out_sc' = 5) & (so' = 5);

  // 5: wait for Final_CoAP_POST from Controller (finalization)
  [] so=5 & chan_ComSC=7 -> (chan_ComSC' = NO_MSG) & (so' = 6);

  // 6: send CoAP_ACK (final ack)
  [] so=6 & out_sc=NO_MSG -> (out_sc' = 1) & (so' = 7);

  // 7: mark auth complete
  [] so=7 -> (auth_complete_SO' = true) & (session_key_SO' = 1) & (so' = 8);

  [] so=8 -> (so' = 8);

  // Error handling
  [] so=1 & chan_ComSC!=2 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 1);
  [] so=3 & chan_ComSC!=3 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 3);
  [] so=5 & chan_ComSC!=7 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (so' = 5);
endmodule

// ===== Module: Controller =====
module Controller
  c : [0..18] init 0;

  // 0: receive LO_CoAP_POST from SO
  [] c=0 & chan_ComSC=8 -> (chan_ComSC' = NO_MSG) & (c' = 1);

  // 1: forward LO_CoAP_POST to AAA (out_ca)
  [] c=1 & out_ca=NO_MSG -> (out_ca' = 8) & (c' = 2);

  // 2: wait for PSK_M1 from AAA
  [] c=2 & chan_ComCA=2 -> (chan_ComCA' = NO_MSG) & (c' = 3);

  // 3: forward PSK_M1 to SO
  [] c=3 & out_sc=NO_MSG -> (out_sc' = 2) & (c' = 4);

  // 4: wait for PSK_M2 from SO
  [] c=4 & chan_ComSC=4 -> (chan_ComSC' = NO_MSG) & (c' = 5);

  // 5: forward PSK_M2 to AAA
  [] c=5 & out_ca=NO_MSG -> (out_ca' = 4) & (c' = 6);

  // 6: wait for PSK_M3 from AAA
  [] c=6 & chan_ComCA=3 -> (chan_ComCA' = NO_MSG) & (c' = 7);

  // 7: forward PSK_M3 to SO
  [] c=7 & out_sc=NO_MSG -> (out_sc' = 3) & (c' = 8);

  // 8: wait for PSK_M4 from SO
  [] c=8 & chan_ComSC=5 -> (chan_ComSC' = NO_MSG) & (c' = 9);

  // 9: forward PSK_M4 to AAA
  [] c=9 & out_ca=NO_MSG -> (out_ca' = 5) & (c' = 10);

  // 10: wait for EAP_Success from AAA
  [] c=10 & chan_ComCA=6 -> (chan_ComCA' = NO_MSG) & (c' = 11);

  // 11: send Final_CoAP_POST to SO
  [] c=11 & out_sc=NO_MSG -> (out_sc' = 7) & (c' = 12);

  // 12: wait for CoAP_ACK from SO
  [] c=12 & chan_ComSC=1 -> (chan_ComSC' = NO_MSG) & (c' = 13);

  // 13: mark auth complete
  [] c=13 -> (auth_complete_Controller' = true) & (c' = 14);

  [] c=14 -> (c' = 14);

  // Error handling
  [] c=0 & chan_ComSC!=8 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 0);
  [] c=2 & chan_ComCA!=2 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (c' = 2);
  [] c=4 & chan_ComSC!=4 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 4);
  [] c=6 & chan_ComCA!=3 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (c' = 6);
  [] c=8 & chan_ComSC!=5 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 8);
  [] c=10 & chan_ComCA!=6 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (c' = 10);
  [] c=12 & chan_ComSC!=1 & chan_ComSC!=NO_MSG -> (chan_ComSC' = NO_MSG) & (c' = 12);
endmodule

// ===== Module: AAA Server =====
module AAA_Server
  a : [0..10] init 0;

  // 0: receive LO_CoAP_POST from Controller (forwarded)
  [] a=0 & chan_ComCA=8 -> (chan_ComCA' = NO_MSG) & (a' = 1);

  // 1: send PSK_M1 to Controller
  [] a=1 & out_ca=NO_MSG -> (out_ca' = 2) & (a' = 2);

  // 2: wait for PSK_M2
  [] a=2 & chan_ComCA=4 -> (chan_ComCA' = NO_MSG) & (a' = 3);

  // 3: send PSK_M3 to Controller
  [] a=3 & out_ca=NO_MSG -> (out_ca' = 3) & (a' = 4);

  // 4: wait for PSK_M4
  [] a=4 & chan_ComCA=5 -> (chan_ComCA' = NO_MSG) & (a' = 5);

  // 5: send EAP_Success (with MSK)
  [] a=5 & out_ca=NO_MSG -> (out_ca' = 6) & (session_key_AAA' = 1) & (a' = 6);

  // 6: mark auth complete
  [] a=6 -> (auth_complete_AAA' = true) & (a' = 7);

  [] a=7 -> (a' = 7);

  // Error handling
  [] a=0 & chan_ComCA!=8 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (a' = 0);
  [] a=2 & chan_ComCA!=4 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (a' = 2);
  [] a=4 & chan_ComCA!=5 & chan_ComCA!=NO_MSG -> (chan_ComCA' = NO_MSG) & (a' = 4);
endmodule

// ===== Channel SC (out_sc -> chan_ComSC) =====
module Channel_SC
  cs : [0..2] init 0;

  // move out_sc -> chan if free (with probabilistic loss)
  [] out_sc!=NO_MSG & chan_ComSC=NO_MSG -> 
      p_loss : (out_sc' = NO_MSG) // lost
    + (1 - p_loss) : (chan_ComSC' = out_sc) & (out_sc' = NO_MSG) & (cs' = 1);

  // model bit-flip corruption while message in channel
  [] cs=1 & chan_ComSC!=NO_MSG ->
     p_flip : (chan_ComSC' = CORRUPT) & (integrity_violation' = true) & (cs' = 1)
   + (1 - p_flip) : (cs' = 1);

  [] cs=1 & chan_ComSC=NO_MSG -> (cs' = 0);
endmodule

// ===== Channel CA (out_ca -> chan_ComCA) =====
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

// ===== Intruder =====
module Intruder
  i : [0..6] init 0;

    // intercept SC-direction emission
  // [intr_intercept_sc] out_sc!=NO_MSG & chan_ComSC=NO_MSG -> (i' = 0); // Removed
  [] out_sc!=NO_MSG & chan_ComSC=NO_MSG -> (intr_buf_sc' = out_sc) & (out_sc' = NO_MSG) & (mitm_detected' = true) & (i' = 1);

  // intercept CA-direction emission
  // [intr_intercept_ca] out_ca!=NO_MSG & chan_ComCA=NO_MSG -> (i' = 0); // Removed
  [] out_ca!=NO_MSG & chan_ComCA=NO_MSG & active_intruder=true -> (intr_buf_ca' = out_ca) & (out_ca' = NO_MSG) & (mitm_detected' = true) & (i' = 1);

  // intercept SC-direction emission
  [] out_sc!=NO_MSG & chan_ComSC=NO_MSG & active_intruder=true -> (intr_buf_sc' = out_sc) & (out_sc' = NO_MSG) & (mitm_detected' = true) & (i' = 1);

  // replay or forward intr_buf_sc
  [] intr_buf_sc!=NO_MSG & chan_ComSC=NO_MSG & active_intruder=true -> (chan_ComSC' = intr_buf_sc) & (intr_buf_sc' = NO_MSG) & (replay_detected' = true) & (i' = 2);
  [] intr_buf_sc!=NO_MSG & chan_ComSC=NO_MSG & active_intruder=true -> (chan_ComSC' = 4) & (intr_buf_sc' = NO_MSG) & (i' = 3);

  // replay or forward intr_buf_ca
  [] intr_buf_ca!=NO_MSG & chan_ComCA=NO_MSG & active_intruder=true -> (chan_ComCA' = intr_buf_ca) & (intr_buf_ca' = NO_MSG) & (replay_detected' = true) & (i' = 2);
  [] intr_buf_ca!=NO_MSG & chan_ComCA=NO_MSG & active_intruder=true -> (chan_ComCA' = 5) & (intr_buf_ca' = NO_MSG) & (i' = 3);

  // learn MSK if holding success message
  [] intr_buf_sc=6 -> (intr_knows_msk' = true) & (intr_buf_sc' = NO_MSG);
  [] intr_buf_ca=6 -> (intr_knows_msk' = true) & (intr_buf_ca' = NO_MSG);

  // forge inject (nondeterministic)
  [] chan_ComSC=NO_MSG & active_intruder=true -> (chan_ComSC' = 4) & (i' = 4); // forge PSK_M2
  [] chan_ComCA=NO_MSG & active_intruder=true -> (chan_ComCA' = 2) & (i' = 4); // forge PSK_M1

    // drop outgoing buffer (DoS)
  [] out_sc!=NO_MSG & active_intruder=true -> (out_sc' = NO_MSG) & (dos_detected' = true) & (i' = 5);
  [] out_ca!=NO_MSG & active_intruder=true -> (out_ca' = NO_MSG) & (dos_detected' = true) & (i' = 5);

  // Reset
  [] i!=0 -> (i' = 0);
endmodule

// ===== Labels =====
label "auth_success" = (auth_complete_SO = true & auth_complete_AAA = true);
label "intruder_knows_msk" = (intr_knows_msk = true);
label "integrity_violation" = (integrity_violation = true);
label "replay_detected" = (replay_detected = true);
label "mitm_detected" = (mitm_detected = true);
label "dos_detected" = (dos_detected = true);
label "key_mismatch" = (session_key_SO != session_key_AAA) & (session_key_SO != 0) & (session_key_AAA != 0);

// ===== Rewards =====
rewards "msgs"
  chan_ComSC!=NO_MSG : 1;
  chan_ComCA!=NO_MSG : 1;
endrewards

rewards "bytes"
  chan_ComSC=8 : 100;  // LO_CoAP_POST (smaller than full POST)
  chan_ComSC=2 : 120;  // PSK_M1
  chan_ComSC=4 : 100;  // PSK_M2
  chan_ComSC=3 : 120;  // PSK_M3
  chan_ComSC=5 : 100;  // PSK_M4
  chan_ComSC=6 : 160;  // EAP_Success
endrewards
