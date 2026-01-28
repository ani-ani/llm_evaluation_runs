module ArrayExtremes(
    input clk,
    input rst_n,
    input start,
    input [3:0] len,
    input signed [7:0] arr [0:15],
    output reg signed [7:0] neg_val,
    output reg neg_valid,
    output reg signed [7:0] pos_val,
    output reg pos_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    // Internal registers
    reg [2:0] state;
    reg [3:0] idx;
    reg signed [7:0] max_neg;
    reg signed [7:0] min_pos;
    reg neg_found;
    reg pos_found;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd20;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            max_neg <= 8'sd0;
            min_pos <= 8'sd0;
            neg_found <= 1'b0;
            pos_found <= 1'b0;
            neg_val <= 8'sd0;
            pos_val <= 8'sd0;
            neg_valid <= 1'b0;
            pos_valid <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    neg_valid <= 1'b0;
                    pos_valid <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        idx <= 4'd0;
                        max_neg <= 8'sd0;
                        min_pos <= 8'sd0;
                        neg_found <= 1'b0;
                        pos_found <= 1'b0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (idx < len) begin
                        // Check current element
                        if (arr[idx] < 8'sd0) begin
                            if (!neg_found || arr[idx] > max_neg) begin
                                max_neg <= arr[idx];
                                neg_found <= 1'b1;
                            end
                        end else if (arr[idx] > 8'sd0) begin
                            if (!pos_found || arr[idx] < min_pos) begin
                                min_pos <= arr[idx];
                                pos_found <= 1'b1;
                            end
                        end
                        idx <= idx + 4'd1;
                    end else begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    neg_val <= max_neg;
                    pos_val <= min_pos;
                    neg_valid <= neg_found;
                    pos_valid <= pos_found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule