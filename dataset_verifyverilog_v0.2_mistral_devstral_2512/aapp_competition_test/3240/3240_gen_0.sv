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

    // Parameters
    localparam IDLE = 3'b000;
    localparam READ_VOTER = 3'b001;
    localparam UPDATE_PDT = 3'b010;
    localparam EVAL_LOOP = 3'b011;
    localparam DONE_STATE = 3'b100;

    // Internal registers
    reg [2:0] state;
    reg [3:0] current_voter;
    reg [3:0] current_sum;
    reg [3:0] current_b_self;
    reg [3:0] current_bit_pos;
    reg [15:0] pdt [0:15];
    reg [15:0] new_pdt [0:15];
    reg [15:0] max_expected_wins;
    reg [15:0] current_expected_wins;
    reg [3:0] best_b_self;

    // Initialize state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_voter <= 0;
            current_sum <= 0;
            current_b_self <= 0;
            current_bit_pos <= 0;
            optimal_b_self <= 0;
            done <= 0;
            max_expected_wins <= 0;
            current_expected_wins <= 0;
            best_b_self <= 0;
            // Initialize PDT
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                pdt[i] <= (i == 0) ? 16'h10000 : 16'h0000;
            end
        end else begin
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= READ_VOTER;
                        current_voter <= 0;
                        done <= 0;
                    end
                end
                READ_VOTER: begin
                    if (voter_valid) begin
                        state <= UPDATE_PDT;
                        current_sum <= 0;
                    end else if (current_voter == 8) begin
                        state <= EVAL_LOOP;
                        current_b_self <= 0;
                        max_expected_wins <= 0;
                        best_b_self <= 0;
                    end else begin
                        current_voter <= current_voter + 1;
                    end
                end
                UPDATE_PDT: begin
                    // Compute new_pdt for current_sum
                    if (current_sum == 0) begin
                        new_pdt[current_sum] <= (pdt[current_sum] * (16'h10000 - voter_prob)) >> 16;
                    end else if (current_sum <= voter_ballot) begin
                        new_pdt[current_sum] <= (pdt[current_sum] * (16'h10000 - voter_prob)) >> 16;
                    end else begin
                        new_pdt[current_sum] <= (pdt[current_sum] * (16'h10000 - voter_prob) + 
                                                pdt[current_sum - voter_ballot] * voter_prob) >> 16;
                    end
                    
                    if (current_sum == 15) begin
                        // Copy new_pdt to pdt
                        integer i;
                        for (i = 0; i < 16; i = i + 1) begin
                            pdt[i] <= new_pdt[i];
                        end
                        if (current_voter == 8) begin
                            state <= EVAL_LOOP;
                            current_b_self <= 0;
                            max_expected_wins <= 0;
                            best_b_self <= 0;
                        end else begin
                            state <= READ_VOTER;
                            current_voter <= current_voter + 1;
                        end
                    end else begin
                        current_sum <= current_sum + 1;
                    end
                end
                EVAL_LOOP: begin
                    // Calculate expected wins for current_b_self
                    if (current_bit_pos == 0) begin
                        current_expected_wins <= 0;
                    end
                    
                    // Calculate probability that bit is set
                    reg [15:0] prob_bit_1 = 0;
                    integer s;
                    for (s = 0; s < 16; s = s + 1) begin
                        if (((s + current_b_self) >> current_bit_pos) & 1) begin
                            prob_bit_1 = prob_bit_1 + pdt[s];
                        end
                    end
                    current_expected_wins <= current_expected_wins + prob_bit_1;
                    
                    if (current_bit_pos == 3) begin
                        // Compare with max
                        if (current_expected_wins > max_expected_wins) begin
                            max_expected_wins <= current_expected_wins;
                            best_b_self <= current_b_self;
                        end
                        
                        if (current_b_self == 15) begin
                            state <= DONE_STATE;
                            optimal_b_self <= best_b_self;
                            done <= 1;
                        end else begin
                            current_b_self <= current_b_self + 1;
                        end
                        current_bit_pos <= 0;
                    end else begin
                        current_bit_pos <= current_bit_pos + 1;
                    end
                end
                DONE_STATE: begin
                    if (!start) begin
                        state <= IDLE;
                        done <= 0;
                    end
                end
            endcase
        end
    end

endmodule