module game_solver (
    input clk,
    input rst_n,
    input start,
    input [127:0] packed_s,
    input [4:0] len,
    output reg [15:0] winner,
    output reg done
);

    // State machine states
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    reg [1:0] state;
    reg [4:0] k;
    reg [7:0] min_char;
    reg [15:0] result;
    reg [7:0] current_char;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            k <= 5'd0;
            min_char <= 8'hFF;
            winner <= 16'b0;
            done <= 1'b0;
            result <= 16'b0;
            current_char <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        k <= 5'd0;
                        min_char <= 8'hFF;
                        result <= 16'b0;
                    end
                end

                COMPUTE: begin
                    if (k < len) begin
                        // Extract current character using part-select
                        current_char <= packed_s[(k * 8) +: 8];
                        
                        // Ann wins if min_char < current_char
                        if (min_char < current_char) begin
                            result[k] <= 1'b1;
                        end else begin
                            result[k] <= 1'b0;
                        end
                        
                        // Update minimum character seen so far
                        if (min_char < current_char) begin
                            min_char <= min_char;
                        end else begin
                            min_char <= current_char;
                        end
                        
                        k <= k + 5'd1;
                    end else begin
                        // Computation complete
                        winner <= result;
                        done <= 1'b1;
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule