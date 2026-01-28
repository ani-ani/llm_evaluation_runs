module bracket_validator(
    input clk,
    input rst_n,
    input start,
    input [15:0] seq_i,
    input [3:0] len_i,
    output reg possible,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] l_reg;          // Start index
    reg [3:0] r_reg;          // End index
    reg [3:0] pos_reg;        // Current position in sequence
    reg [4:0] balance_reg;    // Current balance
    reg [4:0] cycle_count;    // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd255;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            l_reg <= 4'd0;
            r_reg <= 4'd0;
            pos_reg <= 4'd0;
            balance_reg <= 5'd0;
            cycle_count <= 8'd0;
            possible <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    possible <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= CHECK;
                        l_reg <= 4'd0;
                        r_reg <= 4'd0;
                        pos_reg <= 4'd0;
                        balance_reg <= 5'd0;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if we've found a valid sequence
                    if (balance_reg == 5'd0 && pos_reg == len_i) begin
                        possible <= 1'b1;
                        state <= DONE;
                    end
                    // Check if current segment is invalid
                    else if (balance_reg[4] || (balance_reg < 5'd0 && pos_reg < len_i)) begin
                        // Move to next segment
                        if (r_reg == len_i - 1) begin
                            if (l_reg == len_i - 1) begin
                                state <= DONE;
                            end else begin
                                l_reg <= l_reg + 4'd1;
                                r_reg <= l_reg;
                                pos_reg <= 4'd0;
                                balance_reg <= 5'd0;
                            end
                        end else begin
                            r_reg <= r_reg + 4'd1;
                            pos_reg <= 4'd0;
                            balance_reg <= 5'd0;
                        end
                    end
                    // Continue checking current segment
                    else begin
                        // Invert the segment
                        reg invert;
                        if (pos_reg >= l_reg && pos_reg <= r_reg) begin
                            invert = ~seq_i[pos_reg];
                        end else begin
                            invert = seq_i[pos_reg];
                        end
                        
                        // Update balance
                        if (invert) begin
                            balance_reg <= balance_reg + 5'd1;
                        end else begin
                            balance_reg <= balance_reg - 5'd1;
                        end
                        
                        // Move to next position
                        if (pos_reg == len_i - 1) begin
                            pos_reg <= 4'd0;
                        end else begin
                            pos_reg <= pos_reg + 4'd1;
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule