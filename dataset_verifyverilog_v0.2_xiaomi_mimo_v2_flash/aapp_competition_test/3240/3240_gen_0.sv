module binary_town_voting (
    input clk,
    input rst_n,
    input start,
    input [3:0] voter_id,
    input voter_valid,
    input [15:0] voter_prob,
    input [3:0] voter_ballot,
    output reg [3:0] optimal_b_self,
    output reg done
);

    // State Encoding
    localparam IDLE = 3'b000;
    localparam READ_VOTER = 3'b001;
    localparam UPDATE_PDT = 3'b010;
    localparam EVAL_LOOP = 3'b011;
    localparam EVAL_ACCUM = 3'b100;
    localparam DONE = 3'b101;

    // Registers for State Machine
    reg [2:0] current_state, next_state;
    
    // Internal Registers
    reg [3:0] voter_counter;      // 0-8
    reg [3:0] sum_idx;            // 0-15
    reg [3:0] bit_pos;            // 0-3 (also used as phase flag in UPDATE)
    reg [3:0] self_ballot;        // 0-15
    reg update_phase;             // 0: Calc, 1: Write (used in UPDATE_PDT)
    
    // PDT Storage (Inferred RAM)
    // Port A: Read/Write for updates (Address: sum_idx in UPDATE, sum_idx in EVAL)
    // We need dual port or time multiplexing. 
    // We will use a single port RAM with a 1-cycle delay logic or just infer reg array.
    // To be safe and synchronous:
    reg [31:0] pdt_ram [0:15]; 
    
    // Temporary Buffer for Update Phase
    reg [31:0] pdt_buffer [0:15];
    
    // Probabilities and Math Registers
    reg [31:0] prob_vote;         // Q16.16
    reg [31:0] prob_no_vote;      // Q16.16
    reg [31:0] expected_wins_acc; // Q16.16
    reg [31:0] max_expected_wins; // Q16.16
    
    // Combinational Logic for Update Calculation
    // We read from RAM or registers based on current state/indices
    wire [31:0] read_old_s;
    wire [31:0] read_old_sb;
    wire [63:0] prod1;
    wire [63:0] prod2;
    wire [31:0] new_pdt_val;
    wire [4:0] sum_with_self;
    wire bit_is_set;
    
    // Read Logic for Update
    // For first voter (counter==0), PDT is [1.0, 0, 0...]
    assign read_old_s = (voter_counter == 4'd0 && sum_idx == 4'd0) ? 32'h00010000 : 
                        pdt_ram[sum_idx];
                        
    // Check if s-b is valid
    wire sb_valid;
    assign sb_valid = (sum_idx >= voter_ballot);
    wire [3:0] sb_addr;
    assign sb_addr = sum_idx - voter_ballot;
    
    assign read_old_sb = (voter_counter == 4'd0) ? 
                         ((sb_addr == 4'd0) ? 32'h00010000 : 32'h0) : // Init logic
                         (sb_valid ? pdt_ram[sb_addr] : 32'h0);
                         
    // Math
    // (OldS * (1-p) + OldSB * p) >> 16
    // Note: inputs are Q16.16, so products are Q32.32. We want Q16.16 result.
    // We use 64-bit multiplication, then shift right 16.
    assign prod1 = {32'b0, read_old_s} * {32'b0, prob_no_vote}; // 64-bit result
    assign prod2 = {32'b0, read_old_sb} * {32'b0, prob_vote};
    assign new_pdt_val = (prod1 + prod2) >> 16;
    
    // Evaluation Logic
    assign sum_with_self = {1'b0, sum_idx} + {1'b0, self_ballot};
    assign bit_is_set = sum_with_self[bit_pos];
    
    // State Transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) current_state <= IDLE;
        else current_state <= next_state;
    end

    always @(*) begin
        next_state = current_state;
        case (current_state)
            IDLE: if (start) next_state = READ_VOTER;
            
            READ_VOTER: begin
                if (!voter_valid) begin
                    if (voter_counter == 4'd8) next_state = EVAL_LOOP; // End of list, skip
                    else next_state = READ_VOTER; // Skip this ID
                end else begin
                    next_state = UPDATE_PDT;
                end
            end
            
            UPDATE_PDT: begin
                if (update_phase == 1'b0) begin // Calc Phase
                    if (sum_idx == 4'd15) next_state = UPDATE_PDT; // Stay, switch phase
                    else next_state = UPDATE_PDT;
                end else begin // Write Phase
                    if (sum_idx == 4'd15) next_state = READ_VOTER; // Done with voter
                    else next_state = UPDATE_PDT;
                end
            end
            
            EVAL_LOOP: begin
                if (sum_idx > 4'd15) next_state = EVAL_ACCUM; // Finished sums, check max
                else if (bit_pos > 4'd3) next_state = EVAL_ACCUM; // Finished bits, next sum
                else next_state = EVAL_ACCUM; // Accumulate
            end
            
            EVAL_ACCUM: begin
                next_state = EVAL_LOOP; // Always go back to loop to check pointers or continue
            end
            
            DONE: if (start) next_state = IDLE;
            
            default: next_state = IDLE;
        endcase
    end

    // Datapath and Outputs
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            optimal_b_self <= 4'b0;
            done <= 1'b0;
            voter_counter <= 4'b0;
            sum_idx <= 4'b0;
            bit_pos <= 4'b0;
            self_ballot <= 4'b0;
            update_phase <= 1'b0;
            expected_wins_acc <= 32'h0;
            max_expected_wins <= 32'h0;
            prob_vote <= 32'h0;
            prob_no_vote <= 32'h0;
        end else begin
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        voter_counter <= 4'd0;
                        sum_idx <= 4'd0;
                        self_ballot <= 4'd0;
                        max_expected_wins <= 32'h0;
                        optimal_b_self <= 4'd0;
                        // Ensure RAM[0] = 1.0 for init. 
                        // We rely on the READ logic to handle the first voter, 
                        // but we should reset the RAM content if we want to be safe.
                        // Since we can't iterate here, we assume the READ logic handles the initialization values (1.0 at 0, 0 elsewhere).
                        // To be safe: We will clear RAM in the first UPDATE phase if needed, 
                        // or just trust the logic that uses `voter_counter==0` check.
                        // Let's explicitly write 1.0 to pdt_ram[0] to be clean.
                        pdt_ram[0] <= 32'h00010000;
                    end
                end
                
                READ_VOTER: begin
                    if (!voter_valid) begin
                        if (voter_counter != 4'd8) voter_counter <= voter_counter + 1;
                    end else begin
                        // Load probabilities
                        prob_vote <= {16'b0, voter_prob};
                        prob_no_vote <= 32'h00010000 - {16'b0, voter_prob};
                        
                        // Prepare for UPDATE_PDT
                        sum_idx <= 4'd0;
                        update_phase <= 1'b0; // Calc phase
                        
                        // If first voter, ensure RAM is cleared (except 0 which we just wrote, or handle in loop)
                        // We will handle clearing in UPDATE_PDT loop (if sum_idx > 0 and voter_counter==0, write 0 to buffer)
                        // But we already wrote 1.0 to index 0 in IDLE. 
                        // We need to ensure 1..15 are 0. 
                        // We can do this in the Calc phase: 
                        // If voter_counter==0 && sum_idx != 0, we treat old values as 0.
                        // We just need to write 0 to buffer for those indices.
                        // The logic in Calc phase will handle this because `new_pdt_val` will be 0 if old values are 0.
                        // But we are writing to buffer. We need to write to buffer.
                        // Actually, `new_pdt_val` uses `read_old_s` and `read_old_sb`.
                        // If we read `pdt_ram[sum_idx]` and it's garbage, result is garbage.
                        // So we MUST ensure pdt_ram[1..15] is 0.
                        // We can do this in the WRITE phase of the first voter.
                        // If voter_counter==0, in Calc phase we calculate.
                        // But wait, we need OldPDT values. 
                        // If we are at voter_counter==0, we know the distribution is [1, 0, 0...].
                        // We can bypass the RAM read in combinational logic.
                        // Our combinational logic `read_old_s` checks `voter_counter == 0`.
                        // If voter_counter == 0, `read_old_s` is (idx==0) ? 1.0 : 0.
                        // So we are safe.
                        // But we still need to update RAM eventually.
                        // In WRITE phase (voter_counter==0), we will write `pdt_buffer` to RAM.
                        // So RAM will be updated correctly.
                        
                        voter_counter <= voter_counter + 1;
                    end
                end
                
                UPDATE_PDT: begin
                    if (update_phase == 1'b0) begin // Calc Phase
                        // Calculate new value for current sum_idx
                        // Store in buffer
                        pdt_buffer[sum_idx] <= new_pdt_val;
                        
                        // Increment sum_idx
                        if (sum_idx == 4'd15) begin
                            sum_idx <= 4'd0;
                            update_phase <= 1'b1; // Switch to Write Phase
                        end else begin
                            sum_idx <= sum_idx + 1;
                        end
                    end else begin // Write Phase
                        // Write buffer to RAM
                        pdt_ram[sum_idx] <= pdt_buffer[sum_idx];
                        
                        // Increment sum_idx
                        if (sum_idx == 4'd15) begin
                            // Done with voter
                            sum_idx <= 4'd0;
                            update_phase <= 1'b0; // Reset phase for next voter (though we leave state)
                        end else begin
                            sum_idx <= sum_idx + 1;
                        end
                    end
                end
                
                EVAL_LOOP: begin
                    // This state sets up the next operation.
                    // We need to handle the logic flow.
                    // But EVAL_ACCUM will do the work.
                    // We only need to handle the transition logic here? 
                    // No, logic is handled in EVAL_ACCUM.
                    // Just keep state.
                end
                
                EVAL_ACCUM: begin
                    // Check where we are in the loops based on registers
                    // Note: Registers hold values from previous EVAL_ACCUM (or initial)
                    
                    if (sum_idx > 4'd15) begin
                        // 1. Just finished all sums for current self_ballot
                        // Check Max
                        if (expected_wins_acc > max_expected_wins) begin
                            max_expected_wins <= expected_wins_acc;
                            optimal_b_self <= self_ballot;
                        end
                        // Reset for next self_ballot
                        self_ballot <= self_ballot + 1;
                        sum_idx <= 4'd0;
                        expected_wins_acc <= 32'h0;
                        
                    end else if (bit_pos > 4'd3) begin
                        // 2. Just finished bit loop for this sum_idx
                        bit_pos <= 4'd0;
                        sum_idx <= sum_idx + 1;
                        
                    end else begin
                        // 3. Accumulate for current sum_idx and bit_pos
                        // Read pdt_ram[sum_idx] and check bit
                        // Note: We can read pdt_ram directly here.
                        if (bit_is_set) begin
                            expected_wins_acc <= expected_wins_acc + pdt_ram[sum_idx];
                        end
                        bit_pos <= bit_pos + 1;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end

endmodule