module make_impossible(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire seq_0,
    input wire seq_1,
    input wire seq_2,
    input wire seq_3,
    input wire seq_4,
    input wire seq_5,
    input wire seq_6,
    input wire seq_7,
    input wire [3:0] k,
    input wire signed [15:0] cost_0,
    input wire signed [15:0] cost_1,
    input wire signed [15:0] cost_2,
    input wire signed [15:0] cost_3,
    input wire signed [15:0] cost_4,
    input wire signed [15:0] cost_5,
    input wire signed [15:0] cost_6,
    input wire signed [15:0] cost_7,
    output reg signed [15:0] min_cost,
    output reg success,
    output reg done
);

// State declarations
localparam [3:0]
    IDLE         = 4'd0,
    PREPARE      = 4'd1,
    ENUMERATE    = 4'd2,
    COMPUTE_INIT = 4'd3,
    COMPUTE_LOOP = 4'd4,
    COMPUTE_FINAL= 4'd5,
    CHECK        = 4'd6,
    DONE_STATE   = 4'd7;

localparam INF = 8'd255;     
reg [3:0] state, next_state;
reg [7:0] subset;            
reg [7:0] modified_seq_reg;  
reg signed [15:0] current_cost;  
reg [3:0] char_cnt;          
reg [7:0] dp_prev [0:8];     
reg [7:0] dp_current [0:8];  
reg signed [15:0] best_cost_reg; 
reg success_reg;

// Combinational signals
wire [7:0] seq = {seq_7, seq_6, seq_5, seq_4, seq_3, seq_2, seq_1, seq_0};
wire [7:0] modified_seq = seq ^ subset;
wire signed [15:0] cost_sum_comb = 
    (subset[0] ? cost_0 : 16'd0) +
    (subset[1] ? cost_1 : 16'd0) +
    (subset[2] ? cost_2 : 16'd0) +
    (subset[3] ? cost_3 : 16'd0) +
    (subset[4] ? cost_4 : 16'd0) +
    (subset[5] ? cost_5 : 16'd0) +
    (subset[6] ? cost_6 : 16'd0) +
    (subset[7] ? cost_7 : 16'd0);

wire current_char = modified_seq_reg[char_cnt];

integer j;
always @* begin
    for (j = 0; j <= 8; j = j + 1) begin
        dp_current[j] = INF;
    end
    
    if (state == COMPUTE_LOOP) begin
        for (j = 0; j <= 8; j = j + 1) begin
            if (current_char == 1'b0) begin // '('                
                // Bruce doesn't flip (push)
                if (j >= 1 && dp_prev[j-1] + 0 < dp_current[j]) begin
                    dp_current[j] = dp_prev[j-1];
                end
                // Bruce flips (pop)
                if (j < 8 && dp_prev[j+1] + 1 < dp_current[j]) begin
                    dp_current[j] = dp_prev[j+1] + 1;
                end
            end else begin // ')'                
                // Bruce doesn't flip (pop)
                if (j < 8 && dp_prev[j+1] + 0 < dp_current[j]) begin
                    dp_current[j] = dp_prev[j+1];
                end
                // Bruce flips (push)
                if (j >= 1 && dp_prev[j-1] + 1 < dp_current[j]) begin
                    dp_current[j] = dp_prev[j-1] + 1;
                end
            end
        end
    end
end

// Sequential block
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
        done <= 1'b0;
        success <= 1'b0;
        min_cost <= 16'd0;
        subset <= 8'd0;
        modified_seq_reg <= 8'd0;
        current_cost <= 16'd0;
        char_cnt <= 4'd0;
        best_cost_reg <= 16'd32767;
        success_reg <= 1'b0;
        for (integer j = 0; j <= 8; j = j + 1) begin
            dp_prev[j] <= INF;
        end
    end else begin
        case (state)
            IDLE: begin
                done <= 1'b0;
                if (start) begin
                    state <= PREPARE;
                end
            end
            
            PREPARE: begin
                best_cost_reg <= 16'd32767;
                success_reg <= 1'b0;
                subset <= 8'd0;
                state <= ENUMERATE;
            end
            
            ENUMERATE: begin
                modified_seq_reg <= modified_seq;
                current_cost <= cost_sum_comb;
                state <= COMPUTE_INIT;
            end
            
            COMPUTE_INIT: begin
                char_cnt <= 4'd0;
                dp_prev[0] <= 8'd0;
                for (j = 1; j <= 8; j = j + 1) begin
                    dp_prev[j] <= INF;
                end
                state <= COMPUTE_LOOP;
            end
            
            COMPUTE_LOOP: begin
                for (j = 0; j <= 8; j = j + 1) begin
                    dp_prev[j] <= dp_current[j];
                end
                if (char_cnt == 7) begin
                    state <= COMPUTE_FINAL;
                end else begin
                    char_cnt <= char_cnt + 4'd1;
                    state <= COMPUTE_LOOP;
                end
            end
            
            COMPUTE_FINAL: begin
                state <= CHECK;
            end
            
            CHECK: begin
                if (dp_prev[0] <= INF && dp_prev[0] > k) begin
                    success_reg <= 1'b1;
                    if (current_cost < best_cost_reg) begin
                        best_cost_reg <= current_cost;
                    end
                end
                
                if (subset == 8'd255) begin
                    state <= DONE_STATE;
                end else begin
                    subset <= subset + 8'd1;
                    state <= ENUMERATE;
                end
            end
            
            DONE_STATE: begin
                min_cost <= best_cost_reg;
                success <= success_reg;
                done <= 1'b1;
                state <= IDLE;
            end
            
            default: state <= IDLE;
        endcase
    end
end

endmodule