module mirka_composition #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 12,      // Signed: -2048 to 2047
    parameter K_MAX = 100,          // Scaled from 2e9
    parameter K_WIDTH = 8,          // log2(K_MAX) + 1
    parameter RESULT_WIDTH = 5      // Max N=8, need 4 bits + 1
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input [3:0] N,             // Actual sequence length (2-8)
    input signed [DATA_WIDTH-1:0] arr [0:MAX_N-1],
    output reg [RESULT_WIDTH-1:0] max_correct,
    output reg [K_WIDTH-1:0] best_K,
    output reg done
);

// State definitions
localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT_SIM = 3'd1;
localparam [2:0] RUN_SIM = 3'd2;
localparam [2:0] UPDATE_BEST = 3'd3;
localparam [2:0] NEXT_K = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

// Simulation sub-states
localparam [1:0] SIM_SETUP = 2'd0;
localparam [1:0] SIM_LOOP = 2'd1;
localparam [1:0] SIM_FINISH = 2'd2;

// Registers
reg [2:0] state;
reg [1:0] sim_state;
reg [K_WIDTH-1:0] current_k;
reg [RESULT_WIDTH-1:0] current_correct;
reg signed [DATA_WIDTH-1:0] prev_played;
reg [3:0] sim_idx;
reg [3:0] loop_counter;

// Wires
wire signed [DATA_WIDTH-1:0] diff;
wire signed [DATA_WIDTH-1:0] next_played;
wire is_correct;

assign diff = arr[sim_idx] - arr[sim_idx-1];
assign next_played = (diff > 0) ? (prev_played + $signed({1'b0, current_k})) :
                     (diff < 0) ? (prev_played - $signed({1'b0, current_k})) :
                     prev_played;
assign is_correct = (next_played == arr[sim_idx]);

// State machine
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        max_correct <= {RESULT_WIDTH{1'b0}};
        best_K <= {K_WIDTH{1'b0}};
        current_k <= {K_WIDTH{1'b0}};
        current_correct <= {RESULT_WIDTH{1'b0}};
        prev_played <= {DATA_WIDTH{1'b0}};
        sim_idx <= 4'd0;
        sim_state <= SIM_SETUP;
        loop_counter <= 4'd0;
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= INIT_SIM;
                    current_k <= {K_WIDTH{1'b0}};
                    max_correct <= {RESULT_WIDTH{1'b0}};
                    best_K <= {K_WIDTH{1'b0}};
                end
            end
            
            INIT_SIM: begin
                sim_state <= SIM_SETUP;
                loop_counter <= 4'd0;
                current_correct <= {RESULT_WIDTH{1'b0}};
                prev_played <= {DATA_WIDTH{1'b0}};
                sim_idx <= 4'd0;
                state <= RUN_SIM;
            end
            
            RUN_SIM: begin
                case (sim_state)
                    SIM_SETUP: begin
                        current_correct <= {{RESULT_WIDTH-1{1'b0}}, 1'b1};  // Start with 1 correct
                        prev_played <= arr[0];
                        sim_idx <= 4'd1;
                        sim_state <= SIM_LOOP;
                    end
                    
                    SIM_LOOP: begin
                        if (sim_idx < N) begin
                            prev_played <= next_played;
                            if (is_correct) begin
                                current_correct <= current_correct + {{RESULT_WIDTH-1{1'b0}}, 1'b1};
                            end
                            sim_idx <= sim_idx + 4'd1;
                        end else begin
                            sim_state <= SIM_FINISH;
                        end
                        
                        // Timeout safeguard
                        loop_counter <= loop_counter + 4'd1;
                        if (loop_counter >= 4'd15) sim_state <= SIM_FINISH;
                    end
                    
                    SIM_FINISH: begin
                        state <= UPDATE_BEST;
                    end
                    
                    default: sim_state <= SIM_SETUP;
                endcase
            end
            
            UPDATE_BEST: begin
                if (current_correct > max_correct) begin
                    max_correct <= current_correct;
                    best_K <= current_k;
                end
                state <= NEXT_K;
            end
            
            NEXT_K: begin
                if (current_k < K_WIDTH'(K_MAX)) begin
                    current_k <= current_k + {{K_WIDTH-1{1'b0}}, 1'b1};
                    state <= INIT_SIM;
                end else begin
                    state <= DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule