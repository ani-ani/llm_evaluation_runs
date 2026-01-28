module unequal_pair_counter(
    input clk,
    input rst_n,
    input start,
    input [7:0] arr_0,
    input [7:0] arr_1,
    input [7:0] arr_2,
    input [7:0] arr_3,
    input [7:0] arr_4,
    input [7:0] arr_5,
    input [7:0] arr_6,
    input [7:0] arr_7,
    input [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] COMPARE = 3'd1;
    localparam [2:0] FINISH  = 3'd2;

    reg [2:0] state;
    reg [3:0] i_reg;
    reg [3:0] j_reg;
    reg [15:0] count;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            count <= 16'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                        i_reg <= 4'd0;
                        j_reg <= 4'd0;
                        count <= 16'd0;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Check if we've processed all pairs
                    if (i_reg >= len - 1'b1) begin
                        state <= FINISH;
                    end else begin
                        // Compare current pair
                        if (j_reg >= len) begin
                            // Move to next i
                            i_reg <= i_reg + 4'd1;
                            j_reg <= i_reg + 4'd1;
                        end else begin
                            // Perform comparison
                            case (i_reg)
                                4'd0: begin
                                    if (arr_0 != arr_1) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                4'd1: begin
                                    if (arr_1 != arr_2) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                4'd2: begin
                                    if (arr_2 != arr_3) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                4'd3: begin
                                    if (arr_3 != arr_4) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                4'd4: begin
                                    if (arr_4 != arr_5) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                4'd5: begin
                                    if (arr_5 != arr_6) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                4'd6: begin
                                    if (arr_6 != arr_7) count <= count + 16'd1;
                                    j_reg <= j_reg + 4'd1;
                                end
                                default: j_reg <= j_reg + 4'd1;
                            endcase
                        end
                    end

                    // Safety: prevent infinite loops
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    result <= count;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule