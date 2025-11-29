// lo_coap_eap_dtmc.pm
// DTMC Model for Lightweight LO-CoAP-EAP
// Models the optimized message exchange sequence

mdp

// ===== Parameters =====
const double p_loss = 0.02;        // Same channel loss
const double p_attack = 0.001;     // Same active attack prob
const double p_replay = 0.01;      // HIGHER replay risk for LO (simplified handshake)

// ===== States =====
// 0: Initial
// 1..12: Protocol Steps
// 20: Success
// 21: Failed (Loss)
// 22: Compromised (Attack/Replay)

module Protocol
    s : [0..22] init 0;

    // --- Step 1: SO -> Ctrl (LO_CoAP POST + Id Resp) ---
    // Merged step, higher efficiency
        // benign branch: only loss
        [] s=0 -> (1 - p_loss) : (s'=1) + p_loss : (s'=21);
        // adversarial branch: attack possible
        [] s=0 -> p_attack : (s'=22) + (1 - p_attack) : (s'=1);

    // --- Step 2: Ctrl -> AAA (Forward LO_CoAP POST) ---
        [] s=1 -> (1 - p_loss) : (s'=2) + p_loss : (s'=21);
        [] s=1 -> p_attack : (s'=22) + (1 - p_attack) : (s'=2);

    // --- Step 3: AAA -> Ctrl (EAP PSK M1) ---
        [] s=2 -> (1 - p_loss) : (s'=3) + p_loss : (s'=21);
        [] s=2 -> p_attack : (s'=22) + (1 - p_attack) : (s'=3);

    // --- Step 4: Ctrl -> SO (Forward PSK M1) ---
        [] s=3 -> (1 - p_loss) : (s'=4) + p_loss : (s'=21);
        [] s=3 -> p_attack : (s'=22) + (1 - p_attack) : (s'=4);

    // --- Step 5: SO -> Ctrl (EAP PSK M2) ---
        [] s=4 -> (1 - p_loss) : (s'=5) + p_loss : (s'=21);
        [] s=4 -> p_attack : (s'=22) + (1 - p_attack) : (s'=5);

    // --- Step 6: Ctrl -> AAA (Forward PSK M2) ---
        [] s=5 -> (1 - p_loss) : (s'=6) + p_loss : (s'=21);
        [] s=5 -> p_attack : (s'=22) + (1 - p_attack) : (s'=6);

    // --- Step 7: AAA -> Ctrl (EAP PSK M3) ---
        [] s=6 -> (1 - p_loss) : (s'=7) + p_loss : (s'=21);
        [] s=6 -> p_attack : (s'=22) + (1 - p_attack) : (s'=7);

    // --- Step 8: Ctrl -> SO (Forward PSK M3) ---
        [] s=7 -> (1 - p_loss) : (s'=8) + p_loss : (s'=21);
        [] s=7 -> p_attack : (s'=22) + (1 - p_attack) : (s'=8);

    // --- Step 9: SO -> Ctrl (EAP PSK M4) ---
        [] s=8 -> (1 - p_loss) : (s'=9) + p_loss : (s'=21);
        [] s=8 -> p_attack : (s'=22) + (1 - p_attack) : (s'=9);

    // --- Step 10: Ctrl -> AAA (Forward PSK M4) ---
        [] s=9 -> (1 - p_loss) : (s'=10) + p_loss : (s'=21);
        [] s=9 -> p_attack : (s'=22) + (1 - p_attack) : (s'=10);

    // --- Step 11: AAA -> Ctrl (EAP Success) ---
        [] s=10 -> (1 - p_loss) : (s'=11) + p_loss : (s'=21);
        [] s=10 -> p_attack : (s'=22) + (1 - p_attack) : (s'=11);

    // --- Step 12: Ctrl -> SO (Forward Success) ---
    // Higher replay risk here
        [] s=11 -> (1 - p_loss - p_replay) : (s'=20) + p_loss : (s'=21) + p_replay : (s'=22);
        [] s=11 -> p_attack : (s'=22) + (1 - p_attack) : (s'=20);

    // Loops
    [] s=20 -> (s'=20);
    [] s=21 -> (s'=21);
    [] s=22 -> (s'=22);

endmodule

// ===== Rewards =====
rewards "bytes"
    s=0 : 100; // LO_CoAP POST (Optimized)
    s=1 : 100; // Forward
    s=2 : 120; // M1
    s=3 : 120; // M1
    s=4 : 100; // M2
    s=5 : 100; // M2
    s=6 : 120; // M3
    s=7 : 120; // M3
    s=8 : 100; // M4
    s=9 : 100; // M4
    s=10 : 160; // Success
    s=11 : 160; // Success
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
endrewards

// ===== Labels =====
label "auth_success" = s=20;
label "failed" = s=21;
label "compromised" = s=22;
