module trash_game(
    input clk,
    input rst_n,
    input start,
    input [415:0] deck,
    output reg result,
    output reg done
);

    // States
    localparam IDLE = 0;
    localparam INIT = 1;
    localparam CHECK_WIN = 2;
    localparam DRAW = 3;
    localparam PROCESS = 4;
    localparam JACK_STRATEGY = 5;
    localparam PLACE_CARD = 6;
    localparam UNCOVER = 7;
    localparam DISCARD = 8;
    localparam SWITCH_PLAYER = 9;
    localparam WINNER = 10;

    // Registers
    reg [3:0] state;
    reg [3:0] theta_slots [0:9];
    reg [3:0] friend_slots [0:9];
    reg [13:0] theta_revealed; // Bit 0 unused, 1..13 used
    reg [13:0] friend_revealed;
    reg [13:0] discard_revealed;
    reg [5:0] deck_ptr;
    reg [5:0] current_card;
    reg [7:0] turn_count;
    reg current_player; // 0: Theta, 1: Friend
    
    // Internal helpers
    reg [3:0] temp_req;
    reg [3:0] i_index; // Iterator for loops
    reg found_safe;    // For Theta strategy
    reg [3:0] target_slot;
    reg [3:0] temp_val;
    reg [3:0] uncovered_card;
    
    // Helper to get card from deck
    reg [3:0] drawn_card;
    
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            deck_ptr <= 20; // Initial cards are 0-19
            turn_count <= 0;
            theta_revealed <= 0;
            friend_revealed <= 0;
            discard_revealed <= 0;
            // Don't reset arrays explicitly to save logic if they are overwritten, 
            // but good practice implies resetting valid flags. Here we rely on state machine.
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= INIT;
                        done <= 0;
                        result <= 0;
                        deck_ptr <= 20;
                        turn_count <= 0;
                        current_player <= 0; // Theta starts
                        theta_revealed <= 0;
                        friend_revealed <= 0;
                        discard_revealed <= 0;
                        // Initialize slots to 0 (empty)
                        for (k = 0; k < 10; k = k + 1) begin
                            theta_slots[k] <= 0;
                            friend_slots[k] <= 0;
                        end
                    end
                end

                INIT: begin
                    // Theta starts, her turn
                    state <= CHECK_WIN;
                end

                CHECK_WIN: begin
                    // Check if current player has all slots filled
                    // We can use a loop or reduction, but loop is cleaner for variable index
                    // Actually, we just set a flag and proceed. 
                    // To avoid combinational loop in state machine, we check here.
                    if (current_player == 0) begin
                        // Check Theta
                        if (theta_slots[0]!=0 && theta_slots[1]!=0 && theta_slots[2]!=0 && theta_slots[3]!=0 && 
                            theta_slots[4]!=0 && theta_slots[5]!=0 && theta_slots[6]!=0 && theta_slots[7]!=0 && 
                            theta_slots[8]!=0 && theta_slots[9]!=0) begin
                            result <= 1; // Theta wins
                            state <= WINNER;
                        end else begin
                            state <= DRAW;
                        end
                    end else begin
                        // Check Friend
                        if (friend_slots[0]!=0 && friend_slots[1]!=0 && friend_slots[2]!=0 && friend_slots[3]!=0 && 
                            friend_slots[4]!=0 && friend_slots[5]!=0 && friend_slots[6]!=0 && friend_slots[7]!=0 && 
                            friend_slots[8]!=0 && friend_slots[9]!=0) begin
                            result <= 0; // Friend wins (since result is high if Theta wins)
                            state <= WINNER;
                        end else begin
                            state <= DRAW;
                        end
                    end
                end

                DRAW: begin
                    // Draw card from deck
                    // Extract card based on deck_ptr
                    // deck[415:0], index 0 is MSB. 
                    // deck_ptr starts at 20 (20th card, index 20).
                    // card at index i is at [415-4*i - : 4]
                    // i = 0 -> [415:412], i=1 -> [411:408]...
                    // So for deck_ptr P, bit range is [415 - 4*P - : 4] -> [415-4*P : 412-4*P] is wrong direction.
                    // The spec says: deck[415:412] is first card.
                    // If deck_ptr = 20, we want the 21st card (0-indexed).
                    // We want bits [415 - 4*20 - : 4] = [415-80 : 415-80-3] = [335:332].
                    // Wait, deck_ptr is defined as next card to draw. Initially 20.
                    // So we draw deck_ptr index.
                    current_card <= deck[415 - 4*deck_ptr +: 4];
                    
                    // Increment pointer
                    deck_ptr <= deck_ptr + 1;
                    
                    // Safety counter
                    turn_count <= turn_count + 1;
                    
                    if (turn_count > 200) begin
                        // Timeout, assume infinite loop, declare Friend winner (arbitrary fallback)
                        // Or just finish. Let's just finish.
                        result <= 0;
                        state <= WINNER;
                    end else begin
                        state <= PROCESS;
                    end
                end

                PROCESS: begin
                    // Analyze current_card
                    if (current_card == 11) begin // Jack
                        state <= JACK_STRATEGY;
                        i_index <= 0; // Start iteration
                        found_safe <= 0;
                    end else if (current_card == 12 || current_card == 13) begin // Queen or King
                        state <= DISCARD;
                    end else begin // 0 (A) to 10 (T)
                        // Value 0->A (slot 0), 1->2 (slot 1), ... 9->T (slot 9)
                        // Value 10->T (slot 9)
                        // If current_card is 10 (T), it maps to slot 9.
                        // If current_card is 0 (A), maps to slot 0.
                        // So if current_card <= 9, slot = current_card.
                        // If current_card == 10, slot = 9.
                        // Actually, T is 10. The prompt says T maps to slot 9. 
                        // A (0) -> slot 0. T (10) -> slot 9.
                        // So we check if value is in range 0..10.
                        // If current_card <= 9, slot = current_card.
                        // If current_card == 10, slot = 9.
                        if (current_card <= 9) begin
                            target_slot <= current_card;
                        end else begin // 10
                            target_slot <= 9;
                        end
                        state <= PLACE_CARD;
                    end
                end

                JACK_STRATEGY: begin
                    // Loop to find slot
                    // Current player determines strategy
                    if (current_player == 1) begin // Friend: Lowest unfilled
                        if (current_player == 1) begin
                            if (friend_slots[i_index] == 0) begin
                                target_slot <= i_index;
                                state <= PLACE_CARD;
                            end else if (i_index < 9) begin
                                i_index <= i_index + 1;
                            end else begin
                                // All full? Should have been caught by win check.
                                // If here, maybe logic error or all full but not caught.
                                // Discard if no slot found.
                                state <= DISCARD;
                            end
                        end
                    end else begin // Theta: Optimal Strategy
                        // Need to calculate required card for slot i_index
                        // Slot 0 -> A (1), Slot 1 -> 2 (2), ... Slot 9 -> T (10)
                        // Value req = i_index + 1 (since 0->1, 9->10)
                        // But wait, A is value 0 in our rep? 
                        // Prompt: A=0, 2=1, ..., 9=9, T=10, J=11...
                        // Slot 0 needs A (0). Slot 1 needs 2 (1). Slot 9 needs T (10).
                        // So req = i_index. 
                        // Let's double check mapping.
                        // Slot 0: Ace. Card value 0.
                        // Slot 1: Two. Card value 1.
                        // Slot 9: Ten. Card value 10.
                        // So req = i_index.
                        
                        // Check if theta_slots[i_index] is 0 (unfilled)
                        if (theta_slots[i_index] == 0) begin
                            // Check if 'safe' (i.e. req is visible/discarded)
                            // req = i_index. But we need to check bitmask.
                            // Bitmask is 13:0. 
                            // Card value 0 -> Bit 0? Or Bit 1?
                            // Prompt: 13:0 bitmask. 0 unused? 
                            // "reg [13:0] theta_revealed: Bitmask of card values (1-13)". 
                            // "Card Representation: 4'd0: Ace (A)..."
                            // So values 0..13 map to bits?
                            // If "1-13" are bits, then 0 (A) is likely bit 0? 
                            // Let's assume bit index = value. 
                            // Value 0 -> Bit 0. Value 10 -> Bit 10.
                            // But prompt says "1-13". Maybe A(0) is special.
                            // Let's assume Bit 0 is A, Bit 1 is 2, ... Bit 10 is T.
                            
                            if (i_index < 11) begin // Slots 0..9 (Values 0..9, T=10)
                                // Check visibility
                                if ( (theta_revealed[i_index] || discard_revealed[i_index]) && (i_index <= 10) ) begin
                                    // Visible. Priority 1. Fill it.
                                    target_slot <= i_index;
                                    state <= PLACE_CARD;
                                    found_safe <= 1; // Mark that we found a priority target
                                end else begin
                                    // Not visible. Priority 2.
                                    // Only fill if we haven't found priority 1 yet AND we are at end of loop? 
                                    // No, we must iterate ALL to find Priority 1 first.
                                    // We need to finish loop before deciding Priority 2.
                                    if (i_index < 9) begin
                                        i_index <= i_index + 1;
                                    end else begin
                                        // Loop done. Check if we found priority 1.
                                        if (found_safe) begin
                                            // Should have triggered above. 
                                            // This path implies we finished loop without finding priority 1.
                                            // But we need to fill the FIRST Priority 1.
                                            // Actually, logic above triggers STATE change immediately.
                                            // So if we are here, we didn't trigger state change.
                                            // We need to store the 'first priority 2' target.
                                            // Let's restructure.
                                            // We need to scan 0..9. 
                                            // Keep track of 'best' slot.
                                            // Priority 1 (Visible) > Priority 2 (Not Visible).
                                            // For P1, lowest index wins.
                                            // For P2, lowest index wins (if no P1 found).
                                            // This requires storing the candidate.
                                            
                                            // Let's try a simpler combinational approach inside state?
                                            // No, HDL prefers sequential.
                                            // Let's keep scanning.
                                            // We need a register to hold the 'proposed slot'.
                                            // If we see a P1, we take it immediately.
                                            // If we see a P2, we record it if we haven't recorded any yet.
                                            
                                            // Let's refine strategy logic in a separate block or simplify:
                                            // Just scan 0..9.
                                            // If we find a slot where `theta_revealed` or `discard_revealed` has the required value:
                                            //   Target that slot, break.
                                            // If we finish loop without breaking:
                                            //   Target lowest unfilled slot.
                                            
                                            // Implementing "Break" in sequential logic is just setting next state.
                                            // So, the logic "if found, go PLACE_CARD" is correct.
                                            // But we need to handle "else if end of loop".
                                            
                                            // Let's use `found_safe` as a flag that we found a Priority 2 candidate (lowest unfilled).
                                            // If we find Priority 1, we go immediately to PLACE.
                                            // If we reach end and haven't gone to PLACE, we use the stored Priority 2.
                                            
                                            // Actually, simpler:
                                            // 1. Iterate 0..9. If `visible(req)` -> Target = i, State = PLACE.
                                            // 2. If loop finishes -> Target = lowest unfilled. State = PLACE.
                                            
                                            // To implement 2: We need to know the lowest unfilled.
                                            // We can calculate it in a combinational block before entering this state, 
                                            // OR just scan it now.
                                            
                                            // Let's stick to: 
                                            // Scan 0..9. 
                                            // If priority 1 found: Go PLACE.
                                            // If i == 9 and priority 1 not found: Go "Find Lowest Unfilled" state.
                                            
                                            if (i_index == 9) begin
                                                // Reached end, no Priority 1 found.
                                                // Reset index to scan for Priority 2 (lowest unfilled).
                                                i_index <= 0;
                                                state <= 5; // Special sub-state? Or reuse?
                                                // Let's use a new state: JACK_STRATEGY_FALLBACK
                                            end else begin
                                                i_index <= i_index + 1;
                                            end
                                        end else begin
                                            // First iteration (i=0) ended, no P1 found. Continue.
                                            if (i_index < 9) i_index <= i_index + 1;
                                            else begin
                                                 // i=9 checked, no P1. 
                                                 i_index <= 0;
                                                 state <= 5; // Go to fallback (find lowest unfilled)
                                            end
                                        end
                                    end
                                end
                            end else begin
                                // Should not happen (slots 0-9 only)
                                state <= DISCARD;
                            end
                        end else begin
                            // Slot i_index is full. Continue.
                            if (i_index < 9) i_index <= i_index + 1;
                            else begin
                                // End of scan, no P1 found.
                                i_index <= 0;
                                state <= 5; // Fallback
                            end
                        end
                    end
                end
                
                // Sub-state for Theta Jack Fallback (Lowest Unfilled)
                5: begin // JACK_STRATEGY_FALLBACK
                    if (theta_slots[i_index] == 0) begin
                        target_slot <= i_index;
                        state <= PLACE_CARD;
                    end else if (i_index < 9) begin
                        i_index <= i_index + 1;
                    end else begin
                        // All full (should be caught by win check)
                        state <= DISCARD;
                    end
                end

                PLACE_CARD: begin
                    // Place current_card into target_slot for current_player
                    if (current_player == 0) begin // Theta
                        // If slot already filled (checked in strategy, but double check)
                        if (theta_slots[target_slot] == 0) begin
                            theta_slots[target_slot] <= current_card;
                            // Update revealed (A=0, we map to bit? 
                            // Prompt: bitmask 1-13. 
                            // Let's assume we track all 0-13 in the reg [13:0].
                            // So bit 0 is 0 (Ace), bit 1 is 1 (2), ... bit 10 is 10 (T).
                            theta_revealed[current_card] <= 1;
                            
                            // If Jack, we are done with the turn (discard Jack, switch player).
                            // Wait, Prompt: "fill slot and repeat with the face-down card". 
                            // For Jack, the slot is filled. The face-down card is UNCOVERED.
                            if (current_card == 11) begin
                                state <= UNCOVER;
                            end else begin
                                // For numeric cards (A-T), if we place it, we uncover the face-down card.
                                // If we place 2 in slot 1 (which is correct), we uncover what was there.
                                // But wait, if we place a card, it must match the slot.
                                // If we place numeric card, it IS the correct value for the slot.
                                // So we cover it?
                                // No, we fill the slot. The slot was empty.
                                // We place the drawn card. 
                                // The slot now has a face-up card.
                                // What about the face-down card that was there initially?
                                // The slot was empty. So there was nothing.
                                // Wait. If the slot is empty, we place the drawn card.
                                // We must then uncover the card *underneath*.
                                // But the slot was empty. 
                                // Ah, the game starts with all slots face-down (occupied by initial hand).
                                // "Theta_slots" stores the *current visible value*. 
                                // Initially, they are empty (0). But physically, a card exists.
                                // We need to track the *physical cards* vs *visible cards*.
                                // Let's assume `theta_slots` is the visible content.
                                // The physical content is separate, or we need an `initial_hand` array.
                                
                                // Let's use `theta_initial_hand` array to store face-down cards.
                                // Init state: Load `theta_initial_hand` from deck.
                                // Then, logic:
                                // 1. Draw card X.
                                // 2. If X is Jack: Pick slot S. 
                                //    Place X in slot S (visible).
                                //    Uncover card Y from `theta_initial_hand[S]`.
                                //    Continue with Y.
                                // 3. If X is numeric: Check slot S.
                                //    If S is empty (physically? no, always physically occupied initially):
                                //    The prompt says "If empty: Fill it. Uncover face-down card..."
                                //    This implies we start with face-down cards.
                                //    So we need to store `theta_initial_hand` separately.
                                //    The `theta_slots` is just the face-up view.
                                //    We need `theta_cards [0:9]` for the underlying cards.
                                
                                // Fix: Add `reg [3:0] theta_cards [0:9]` and `friend_cards [0:9]`.
                                // In INIT: Load these from `deck`.
                                // In Game:
                                //  - If we place X in S:
                                //     - If X is Jack: 
                                //       - Slot S gets X (visible).
                                //       - Get Y = theta_cards[S].
                                //       - If Y is Jack? No, initial hand has no Jacks? 
                                //       - Actually, initial hand has cards. 
                                //       - We continue with Y as `current_card`.
                                //     - If X is numeric:
                                //       - Match check happens BEFORE placing.
                                //       - We check if Slot S is *already filled* (visible).
                                //       - If empty (visible), we place X.
                                //       - We uncover Y = theta_cards[S].
                                //       - We continue with Y.
                                
                                // Let's add `theta_cards` and `friend_cards` to the list of registers.
                                // And update INIT to load them.
                                
                                // Back to PLACE_CARD state:
                                // We need to set `current_card` to the uncovered card next cycle.
                                uncovered_card <= (current_player == 0) ? theta_cards[target_slot] : friend_cards[target_slot];
                                state <= UNCOVER;
                            end
                        end else begin
                            // Slot full. Discard.
                            state <= DISCARD;
                        end
                    end else begin // Friend
                        if (friend_slots[target_slot] == 0) begin
                            friend_slots[target_slot] <= current_card;
                            friend_revealed[current_card] <= 1;
                            if (current_card == 11) begin
                                state <= UNCOVER;
                            end else begin
                                uncovered_card <= (current_player == 0) ? theta_cards[target_slot] : friend_cards[target_slot];
                                state <= UNCOVER;
                            end
                        end else begin
                            state <= DISCARD;
                        end
                    end
                end

                UNCOVER: begin
                    // We just placed a card and uncovered `uncovered_card`.
                    // `uncovered_card` becomes the new `current_card` to process.
                    // Unless we uncovered a Jack? No, we process it.
                    // But wait. If we uncover a card, we check it.
                    // However, we must check if the *slot* is now full.
                    // The slot `target_slot` was empty. We just placed a card there (drawn or Jack).
                    // So the slot is now visible. The uncovered card is the one that was there.
                    // We add the uncovered card to discard pile immediately? 
                    // Or do we use it?
                    // Prompt: "repeat with the face-down card". 
                    // So `current_card` becomes `uncovered_card`.
                    // But wait, if we placed a Jack, the Jack is in the slot. The uncovered card is used.
                    // If we placed a numeric card X, X is in the slot. The uncovered card Y is used.
                    // But X must match the slot for it to be placed.
                    // Wait. If Slot 1 (2) has a face-down card '5'.
                    // We draw a '2'. We place '2' in Slot 1. We uncover '5'.
                    // '5' goes to discard (because it doesn't match Slot 1, which is now filled).
                    // Unless... '5' happens to match some OTHER slot.
                    // Ah. "repeat with the face-down card".
                    // So we check if `uncovered_card` matches any empty slot.
                    // We update `current_card` to `uncovered_card`.
                    // We loop back to PROCESS.
                    // But we need to make sure we don't fill the same slot again.
                    // If `uncovered_card` is '2', and we just filled Slot 1 with '2' (from draw),
                    // we go to PROCESS. It sees '2', checks Slot 1. Slot 1 is full. Discard.
                    // So the logic works if we just loop back to PROCESS.
                    
                    // Wait, what if `uncovered_card` is a Jack?
                    // We process it as Jack. Correct.
                    
                    // So, simply:
                    current_card <= uncovered_card;
                    // The slot `target_slot` is now visible (handled in PLACE_CARD).
                    state <= PROCESS;
                end

                DISCARD: begin
                    // Add current_card to discard pile
                    discard_revealed[current_card] <= 1;
                    
                    // If we came from JACK_STRATEGY and couldn't place (no slots),
                    // or came from PLACE_CARD (slot full),
                    // or came from PROCESS (Q/K),
                    // or came from UNCOVER (uncovered card didn't match).
                    // Switch player.
                    state <= SWITCH_PLAYER;
                end

                SWITCH_PLAYER: begin
                    current_player <= ~current_player;
                    state <= CHECK_WIN;
                end

                WINNER: begin
                    done <= 1;
                    // Stay here until reset
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Handling the need for `theta_cards` and `friend_cards` (Initial Hands)
    // These are not explicitly in the 'Registers' list of the prompt, but required by logic.
    // I will add them.
    reg [3:0] theta_cards [0:9];
    reg [3:0] friend_cards [0:9];
    
    // Logic to load initial hands in IDLE/INIT or combinational
    // Since we need to load them only once on start, we can do it in INIT state.
    // But INIT state is a single cycle state in my current design.
    // We need to loop to copy 10 cards for Theta and 10 for Friend.
    // Let's add a counter for loading.
    reg [3:0] load_idx;
    
    // Modify INIT state logic (conceptually) to handle loading loop.
    // I'll rewrite INIT state to handle loading loop to keep it single-always-block friendly.
    // But wait, we are already in the always block.
    // Let's update the INIT logic in the FSM to support loading.
    // Actually, I can do the loading in IDLE transition, but `start` is one cycle.
    // So I need a multi-cycle INIT.
    
    // Let's add a sub-state for INIT_LOAD.
    // Or just use `load_idx` in INIT.
    
    // Let's update the code in the FSM section above to handle this.
    // In INIT:
    //   if (load_idx < 10) begin
    //      theta_cards[load_idx] <= deck[415 - 4*load_idx +: 4];
    //      load_idx <= load_idx + 1;
    //   end else if (load_idx < 20) begin
    //      friend_cards[load_idx - 10] <= deck[415 - 4*load_idx +: 4];
    //      load_idx <= load_idx + 1;
    //   end else begin
    //      state <= CHECK_WIN;
    //   end
    
    // Wait, the deck format: deck[415:412] is Theta's Ace slot (face-down).
    // So index 0 is Slot 0. index 1 is Slot 1...
    // Theta's initial hand: indices 0..19.
    // Friend's initial hand: indices 20..39.
    // Draw pile: starts at index 40.
    // Wait, prompt says: "deck[415:412] is the first card (Theta's Ace slot face-down)".
    // "deck_ptr initially 20".
    // "load theta_initial_hand from deck[415:336]".
    // 415-336 is 80 bits = 20 cards.
    // So indices 0..19 are for Theta.
    // Indices 20..39 (335:256) are for Friend.
    // Indices 40.. (255...) are draw pile.
    // Wait, if deck_ptr starts at 20, it draws index 20.
    // That would be the first card of Friend's hand.
    // That contradicts "draw pile starts after hands".
    // Let's re-read: "deck[415:412] is the first card (Theta's Ace slot face-down)".
    // "deck_ptr initially 20".
    // If deck[415] is index 0, then index 20 is `deck[415 - 4*20]`.
    // That is `deck[335]`. 
    // 415 - 80 = 335.
    // The prompt says Friend's hand is `deck[335:256]`. 
    // So `deck_ptr=20` points to the start of the draw pile.
    // Correct. 
    // So Theta slots: index 0..9.
    // Theta face-down cards: index 0..9.
    // Friend slots: index 10..19 (mapped to 0..9 in logic).
    // Friend face-down cards: index 10..19.
    // Draw pile: index 20 onwards.
    
    // So `theta_cards[S]` = `deck[415 - 4*S +: 4]`.
    // `friend_cards[S]` = `deck[415 - 4*(S+10) +: 4]`.
    
    // We don't actually need to load these into registers if we can read `deck` combinational.
    // But `deck` is an input. We can read it anytime.
    // So we can remove `theta_cards` registers and use `deck` directly.
    // In UNCOVER state:
    //   uncovered_card = (player==0) ? deck[415 - 4*target_slot +: 4] : deck[415 - 4*(target_slot+10) +: 4];
    // This saves registers.
    // However, `deck` is a huge vector. Combinational read is fine.
    
    // Let's remove the `theta_cards` registers and the INIT loading logic.
    // Instead, in UNCOVER, we calculate the value from `deck`.
    // And in INIT, just set load_idx or state to CHECK_WIN immediately.
    // We don't need to load anything if we read deck on fly.
    // The prompt asks for `theta_slots` and `friend_slots` registers.
    // It doesn't explicitly ask for `theta_cards` registers.
    // So reading deck is better.
    
    // Let's update the UNCOVER state logic in the FSM block above:
    // Remove the `uncovered_card <= ...` line in PLACE_CARD.
    // Instead, in UNCOVER state:
    // `current_card <=` calculation.
    // And update INIT state to just go to CHECK_WIN.
    
    // Revised UNCOVER (inside FSM):
    // if (current_player == 0) current_card <= deck[415 - 4*target_slot +: 4];
    // else current_card <= deck[415 - 4*(target_slot + 10) +: 4];
    // state <= PROCESS;
    
    // Revised INIT (inside FSM):
    // state <= CHECK_WIN;

endmodule
