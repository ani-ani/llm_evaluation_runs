module has_close_elements(
    input clk,
    input rst_n,
    input start,
    input [31:0] threshold,
    input [31:0] arr_0, arr_1, arr_2, arr_3,
    input [31:0] arr_4, arr_5, arr_6, arr_7,
    output reg result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPARE = 2'd1;
    localparam [1:0] DONE    = 2'd2;

    // Registers
    reg [1:0] state;
    reg [7:0] cycle_count;
    reg [2:0] i_reg;
    reg [2:0] j_reg;
    reg [31:0] diff;
    reg [31:0] abs_diff;
    reg found;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 1'b0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            i_reg <= 3'd0;
            j_reg <= 3'd0;
            diff <= 32'd0;
            abs_diff <= 32'd0;
            found <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 1'b0;
                    found <= 1'b0;
                    i_reg <= 3'd0;
                    j_reg <= 3'd0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPARE;
                    end
                end

                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate difference
                    case (i_reg)
                        3'd0: diff = arr_0 - arr_1;
                        3'd1: diff = arr_0 - arr_2;
                        3'd2: diff = arr_0 - arr_3;
                        3'd3: diff = arr_0 - arr_4;
                        3'd4: diff = arr_0 - arr_5;
                        3'd5: diff = arr_0 - arr_6;
                        3'd6: diff = arr_0 - arr_7;
                        3'd7: diff = arr_1 - arr_2;
                        3'd8: diff = arr_1 - arr_3;
                        3'd9: diff = arr_1 - arr_4;
                        3'd10: diff = arr_1 - arr_5;
                        3'd11: diff = arr_1 - arr_6;
                        3'd12: diff = arr_1 - arr_7;
                        3'd13: diff = arr_2 - arr_3;
                        3'd14: diff = arr_2 - arr_4;
                        3'd15: diff = arr_2 - arr_5;
                        3'd16: diff = arr_2 - arr_6;
                        3'd17: diff = arr_2 - arr_7;
                        3'd18: diff = arr_3 - arr_4;
                        3'd19: diff = arr_3 - arr_5;
                        3'd20: diff = arr_3 - arr_6;
                        3'd21: diff = arr_3 - arr_7;
                        3'd22: diff = arr_4 - arr_5;
                        3'd23: diff = arr_4 - arr_6;
                        3'd24: diff = arr_4 - arr_7;
                        3'd25: diff = arr_5 - arr_6;
                        3'd26: diff = arr_5 - arr_7;
                        3'd27: diff = arr_6 - arr_7;
                        default: diff = 32'd0;
                    endcase
                    
                    // Absolute value
                    abs_diff = diff[31] ? -diff : diff;
                    
                    // Compare with threshold
                    if (abs_diff < threshold) begin
                        found <= 1'b1;
                    end
                    
                    // Update counters
                    if (i_reg == 3'd27) begin
                        state <= DONE;
                    end else begin
                        i_reg <= i_reg + 3'd1;
                    end
                end

                DONE: begin
                    result <= found;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule