module SubarraySearch(
    input clk,
    input rst_n,
    input start,
    input [7:0] a [0:7],
    input [7:0] b [0:7],
    input [2:0] n,
    input [2:0] m,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] SEARCH  = 2'd1;
    localparam [1:0] FINISH  = 2'd2;

    reg [1:0] state;
    reg [2:0] pos;
    reg [2:0] i;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd64;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            pos <= 3'd0;
            i <= 3'd0;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= SEARCH;
                        pos <= 3'd0;
                        i <= 3'd0;
                    end
                end

                SEARCH: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (pos + i >= n || (pos + m > n)) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end else if (i == m) begin
                        result <= 1'b1;
                        state <= FINISH;
                    end else if (a[pos + i] == b[i]) begin
                        i <= i + 3'd1;
                    end else begin
                        pos <= pos + 3'd1;
                        i <= 3'd0;
                    end
                    
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= 1'b0;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule