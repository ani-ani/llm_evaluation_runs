module mirka_composition #(
    parameter MAX_N = 8,
    parameter DATA_WIDTH = 12,
    parameter K_MAX = 100,
    parameter K_WIDTH = 8,
    parameter RESULT_WIDTH = 5
) (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] N,
    input wire signed [DATA_WIDTH-1:0] arr [0:MAX_N-1],
    output reg [RESULT_WIDTH-1:0] max_correct,
    output reg [K_WIDTH-1:0] best_K,
    output reg done
);

localparam [2:0] IDLE = 3'd0;
localparam [2:0] INIT_SIM = 3'd1;
localparam [2:0] RUN_SIM = 3'd2;
localparam [2:0] UPDATE_BEST = 3'd3;
localparam [2:0] NEXT_K = 3'd4;
localparam [2:0] DONE_STATE = 3'd5;

localparam [1:0] SIM_SETUP = 2'd0;
localparam [1:0] SIM_LOOP = 2'd1;
localparam [1:0] SIM_FINISH = 2'd2;

reg [2:0] state;
reg [1:0] sim_state;
reg [K_WIDTH-1:0] current_k;
reg [RESULT_WIDTH-1:0] current_correct;
reg signed [DATA_WIDTH-1:0] prev_played;
reg [3:0] sim_idx;
reg [RESULT_WIDTH-1:0] temp_max_correct;
reg [K_WIDTH-1:0] temp_best_K;
reg signed [DATA_WIDTH-1:0] next_played_reg;
reg is_correct_reg;

wire signed [DATA_WIDTH-1:0] diff;
assign diff = arr[sim_idx] - arr[sim_idx-1];

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 0;
        max_correct <= 0;
        best_K <= 0;
        current_k <= 0;
        current_correct <= 0;
        prev_played <= 0;
        sim_idx <= 0;
        sim_state <= SIM_SETUP;
        next_played_reg <= 0;
        is_correct_reg <= 0;
        temp_max_correct <= 0;
        temp_best_K <= 0;
    end else begin
        case (state)
            IDLE: begin
                done <= 0;
                if (start) begin
                    state <= INIT_SIM;
                    current_k <= 0;
                    temp_max_correct <= 0;
                    temp_best_K <= 0;
                end
            end
            
            INIT_SIM: begin
                sim_state <= SIM_SETUP;
                state <= RUN_SIM;
            end
            
            RUN_SIM: begin
                case (sim_state)
                    SIM_SETUP: begin
                        current_correct <= 1;
                        prev_played <= arr[0];
                        sim_idx <= 1;
                        sim_state <= SIM_LOOP;
                    end
                    
                    SIM_LOOP: begin
                        if (sim_idx < N) begin
                            if (diff > 0) begin
                                next_played_reg <= prev_played + $signed({1'b0, current_k});
                            end else if (diff < 0) begin
                                next_played_reg <= prev_played - $signed({1'b0, current_k});
                            end else begin
                                next_played_reg <= prev_played;
                            end
                            
                            if (next_played_reg == arr[sim_idx]) begin
                                is_correct_reg <= 1;
                                current_correct <= current_correct + 1;
                            end else begin
                                is_correct_reg <= 0;
                            end
                            
                            prev_played <= next_played_reg;
                            sim_idx <= sim_idx + 1;
                        end else begin
                            sim_state <= SIM_FINISH;
                        end
                    end
                    
                    SIM_FINISH: begin
                        state <= UPDATE_BEST;
                    end
                    
                    default: sim_state <= SIM_SETUP;
                endcase
            end
            
            UPDATE_BEST: begin
                if (current_correct > temp_max_correct) begin
                    temp_max_correct <= current_correct;
                    temp_best_K <= current_k;
                end
                state <= NEXT_K;
            end
            
            NEXT_K: begin
                if (current_k < K_MAX) begin
                    current_k <= current_k + 1;
                    state <= INIT_SIM;
                end else begin
                    max_correct <= temp_max_correct;
                    best_K <= temp_best_K;
                    state <= DONE_STATE;
                end
            end
            
            DONE_STATE: begin
                done <= 1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule