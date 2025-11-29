// coap_eap_dtmc.pm
// DTMC Model for Standard CoAP-EAP
// Models the full message exchange sequence with probabilistic loss and attacks

mdp

// ===== Parameters =====
const double p_loss = 0.02;        // Probability of packet loss per hop
const double p_attack = 0.001;     // Probability of active attack (MITM/Forge) per hop
const double p_replay = 0.0001;    // Low replay risk for Standard (has full handshake)

// ===== States =====
// 0: Initial
// 1..15: Protocol Steps
// 20: Success
// 21: Failed (Loss)
// 22: Compromised (Attack/Replay)

module Protocol
    s : [0..22] init 0;

        // --- Step 1: SO -> Ctrl (CoAP POST) ---
        // Two nondeterministic alternatives: benign (loss only) vs adversarial (attack possible)
        [] s=0 -> (1 - p_loss) : (s'=1) + p_loss : (s'=21);
        [] s=0 -> p_attack : (s'=22) + (1 - p_attack) : (s'=1);

    // --- Step 2: Ctrl -> SO (CoAP ACK) ---
        [] s=1 -> (1 - p_loss) : (s'=2) + p_loss : (s'=21);
        [] s=1 -> p_attack : (s'=22) + (1 - p_attack) : (s'=2);

    // --- Step 3: Ctrl -> SO (EAP Identity Req) ---
        [] s=2 -> (1 - p_loss) : (s'=3) + p_loss : (s'=21);
        [] s=2 -> p_attack : (s'=22) + (1 - p_attack) : (s'=3);

    // --- Step 4: SO -> Ctrl (EAP Identity Resp) ---
        [] s=3 -> (1 - p_loss) : (s'=4) + p_loss : (s'=21);
        [] s=3 -> p_attack : (s'=22) + (1 - p_attack) : (s'=4);

    // --- Step 5: Ctrl -> AAA (Forward Id Resp) ---
        [] s=4 -> (1 - p_loss) : (s'=5) + p_loss : (s'=21);
        [] s=4 -> p_attack : (s'=22) + (1 - p_attack) : (s'=5);

    // --- Step 6: AAA -> Ctrl (EAP PSK M1) ---
        [] s=5 -> (1 - p_loss) : (s'=6) + p_loss : (s'=21);
        [] s=5 -> p_attack : (s'=22) + (1 - p_attack) : (s'=6);

    // --- Step 7: Ctrl -> SO (Forward PSK M1) ---
        [] s=6 -> (1 - p_loss) : (s'=7) + p_loss : (s'=21);
        [] s=6 -> p_attack : (s'=22) + (1 - p_attack) : (s'=7);

    // --- Step 8: SO -> Ctrl (EAP PSK M2) ---
        [] s=7 -> (1 - p_loss) : (s'=8) + p_loss : (s'=21);
        [] s=7 -> p_attack : (s'=22) + (1 - p_attack) : (s'=8);

    // --- Step 9: Ctrl -> AAA (Forward PSK M2) ---
        [] s=8 -> (1 - p_loss) : (s'=9) + p_loss : (s'=21);
        [] s=8 -> p_attack : (s'=22) + (1 - p_attack) : (s'=9);

    // --- Step 10: AAA -> Ctrl (EAP PSK M3) ---
        [] s=9 -> (1 - p_loss) : (s'=10) + p_loss : (s'=21);
        [] s=9 -> p_attack : (s'=22) + (1 - p_attack) : (s'=10);

    // --- Step 11: Ctrl -> SO (Forward PSK M3) ---
        [] s=10 -> (1 - p_loss) : (s'=11) + p_loss : (s'=21);
        [] s=10 -> p_attack : (s'=22) + (1 - p_attack) : (s'=11);

    // --- Step 12: SO -> Ctrl (EAP PSK M4) ---
        [] s=11 -> (1 - p_loss) : (s'=12) + p_loss : (s'=21);
        [] s=11 -> p_attack : (s'=22) + (1 - p_attack) : (s'=12);

    // --- Step 13: Ctrl -> AAA (Forward PSK M4) ---
        [] s=12 -> (1 - p_loss) : (s'=13) + p_loss : (s'=21);
        [] s=12 -> p_attack : (s'=22) + (1 - p_attack) : (s'=13);

    // --- Step 14: AAA -> Ctrl (EAP Success) ---
        [] s=13 -> (1 - p_loss) : (s'=14) + p_loss : (s'=21);
        [] s=13 -> p_attack : (s'=22) + (1 - p_attack) : (s'=14);

    // --- Step 15: Ctrl -> SO (Forward Success) ---
    // Final step checks for replay as well (though low prob)
        [] s=14 -> (1 - p_loss - p_replay) : (s'=20) + p_loss : (s'=21) + p_replay : (s'=22);
        [] s=14 -> p_attack : (s'=22) + (1 - p_attack) : (s'=20);

    // Loops
    [] s=20 -> (s'=20);
    [] s=21 -> (s'=21);
    [] s=22 -> (s'=22);

endmodule

// ===== Rewards =====
rewards "bytes"
    s=0 : 140; // CoAP POST
    s=1 : 80;  // CoAP ACK
    s=2 : 40;  // Id Req
    s=3 : 60;  // Id Resp
    s=4 : 60;  // Id Resp (fwd)
    s=5 : 120; // M1
    s=6 : 120; // M1 (fwd)
    s=7 : 100; // M2
    s=8 : 100; // M2 (fwd)
    s=9 : 120; // M3
    s=10 : 120; // M3 (fwd)
    s=11 : 100; // M4
    s=12 : 100; // M4 (fwd)
    s=13 : 160; // Success
    s=14 : 160; // Success (fwd)
endrewards

rewards "msgs"
    s=0 : 1;
    s=1 : 1;
    s=2 : 1;
    s=3 : 1;
    s=4 : 1;
    s=5 : 1;
    s=6 : 1;
    s=7 : 1;
    s=8 : 1;
    s=9 : 1;
    s=10 : 1;
    s=11 : 1;
    s=12 : 1;
    s=13 : 1;
    s=14 : 1;
endrewards

// ===== Labels =====
label "auth_success" = s=20;
label "failed" = s=21;
label "compromised" = s=22;
