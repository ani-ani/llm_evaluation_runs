module max_points #(
    parameter MAX_VAL = 64,
    parameter MAX_INPUT_LEN = 16,
    parameter VAL_BITS = 6,
    parameter CNT_BITS = 5,
    parameter RESULT_BITS = 16
)(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [VAL_BITS-1:0] arr [0:MAX_INPUT_LEN-1],
    input wire [3:0] len,
    output wire [RESULT_BITS-1:0] result,
    output wire done
);
    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] LOAD = 2'd1;
    localparam [1:0] DP = 2'd2;
    localparam [1:0] DONE = 2'd3;

    reg [1:0] state, next_state;
    reg [3:0] load_idx;
    reg [5:0] dp_idx;
    reg [CNT_BITS-1:0] freq [0:MAX_VAL-1];
    reg [RESULT_BITS-1:0] dp_prev, dp_curr;
    reg [RESULT_BITS-1:0] result_reg;
    reg done_reg;

    wire [RESULT_BITS-1:0] contribution;
    wire [RESULT_BITS-1:0] dp_new;

    assign contribution = dp_idx * freq[dp_idx];
    assign dp_new = (dp_curr > (dp_prev + contribution)) ? dp_curr : (dp_prev + contribution);
    assign result = result_reg;
    assign done = done_reg;

    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            load_idx <= 4'd0;
            dp_idx <= 6'd0;
            dp_prev <= {RESULT_BITS{1'b0}};
            dp_curr <= {RESULT_BITS{1'b0}};
            result_reg <= {RESULT_BITS{1'b0}};
            done_reg <= 1'b0;
            for (i = 0; i < MAX_VAL; i = i + 1) begin
                freq[i] <= {CNT_BITS{1'b0}};
            end
        end else begin
            done_reg <= 1'b0;
            case (state)
                IDLE: begin
                    if (start) begin
                        state <= LOAD;
                        load_idx <= 4'd0;
                        for (i = 0; i < MAX_VAL; i = i + 1) begin
                            freq[i] <= {CNT_BITS{1'b0}};
                        end
                    end
                end
                
                LOAD: begin
                    if (load_idx < len) begin
                        freq[arr[load_idx]] <= freq[arr[load_idx]] + {{(CNT_BITS-1){1'b0}}, 1'b1};
                        load_idx <= load_idx + 4'd1;
                    end else begin
                        state <= DP;
                        dp_idx <= 6'd0;
                        dp_prev <= {RESULT_BITS{1'b0}};
                        dp_curr <= {RESULT_BITS{1'b0}};
                    end
                end
                
                DP: begin
                    if (dp_idx < MAX_VAL) begin
                        dp_prev <= dp_curr;
                        dp_curr <= dp_new;
                        dp_idx <= dp_idx + 6'd1;
                    end else begin
                        state <= DONE;
                        result_reg <= dp_curr;
                        done_reg <= 1'b1;
                    end
                end
                
                DONE: begin
                    done_reg <= 1'b0;
                    state <= IDLE;
                end
                
                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule