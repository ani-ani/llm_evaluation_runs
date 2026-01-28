module sum_even_even_pos (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_0,
    input wire [7:0] arr_1,
    input wire [7:0] arr_2,
    input wire [7:0] arr_3,
    input wire [7:0] arr_4,
    input wire [7:0] arr_5,
    input wire [7:0] arr_6,
    input wire [7:0] arr_7,
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] CHECK   = 2'd1;
    localparam [1:0] ADD     = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    // Internal registers
    reg [1:0] state;
    reg [3:0] idx;
    reg [15:0] sum_reg;
    reg [7:0] current_val;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Combinational logic to select current array element
    always @(*) begin
        case(idx)
            4'd0: current_val = arr_0;
            4'd1: current_val = arr_1;
            4'd2: current_val = arr_2;
            4'd3: current_val = arr_3;
            4'd4: current_val = arr_4;
            4'd5: current_val = arr_5;
            4'd6: current_val = arr_6;
            4'd7: current_val = arr_7;
            default: current_val = 8'd0;
        endcase
    end

    // Main state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            idx <= 4'd0;
            sum_reg <= 16'd0;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        idx <= 4'd0;
                        sum_reg <= 16'd0;
                        state <= CHECK;
                    end
                end

                CHECK: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (idx < len && cycle_count < MAX_CYCLES) begin
                        // Check if index is even AND value is even
                        if (!idx[0] && !current_val[0]) begin
                            state <= ADD;
                        end else begin
                            // Move to next index
                            if (idx + 1 >= len) begin
                                state <= FINISH;
                            end else begin
                                idx <= idx + 1;
                                state <= CHECK;
                            end
                        end
                    end else begin
                        state <= FINISH;
                    end
                end

                ADD: begin
                    sum_reg <= sum_reg + current_val;
                    // Move to next index after adding
                    if (idx + 1 >= len) begin
                        state <= FINISH;
                    end else begin
                        idx <= idx + 1;
                        state <= CHECK;
                    end
                end

                FINISH: begin
                    result <= sum_reg;
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule