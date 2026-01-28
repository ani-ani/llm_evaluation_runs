module cube_array(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [23:0] result,
    output reg result_valid,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE    = 3'd0;
    localparam [2:0] LOAD    = 3'd1;
    localparam [2:0] MULT1   = 3'd2;
    localparam [2:0] MULT2   = 3'd3;
    localparam [2:0] OUTPUT  = 3'd4;
    localparam [2:0] DONE_STATE = 3'd5;

    // Internal registers
    reg [2:0] state, next_state;
    reg [7:0] current_element;
    reg [15:0] mult_result;
    reg [3:0] element_index;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Multiplier instantiation (8x8->16)
    wire [15:0] mult_out;
    reg [7:0] mult_a, mult_b;

    assign mult_out = mult_a * mult_b;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 24'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
            current_element <= 8'd0;
            mult_result <= 16'd0;
            element_index <= 4'd0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end else begin
                    next_state = IDLE;
                end
            end

            LOAD: begin
                next_state = MULT1;
            end

            MULT1: begin
                next_state = MULT2;
            end

            MULT2: begin
                next_state = OUTPUT;
            end

            OUTPUT: begin
                if (element_index == len - 1) begin
                    next_state = DONE_STATE;
                end else begin
                    next_state = LOAD;
                end
            end

            DONE_STATE: begin
                next_state = IDLE;
            end

            default: next_state = IDLE;
        endcase
    end

    // Datapath logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_element <= 8'd0;
            mult_result <= 16'd0;
            element_index <= 4'd0;
            cycle_count <= 8'd0;
            result <= 24'd0;
            result_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                end

                LOAD: begin
                    current_element <= arr[element_index];
                    mult_a <= current_element;
                    mult_b <= current_element;
                    result_valid <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                end

                MULT1: begin
                    mult_result <= mult_out;
                    mult_a <= mult_result[15:8];
                    mult_b <= current_element;
                    result_valid <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                end

                MULT2: begin
                    result <= {mult_result[15:0], mult_out[15:0]};
                    result_valid <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                end

                OUTPUT: begin
                    result_valid <= 1'b1;
                    element_index <= element_index + 4'd1;
                    cycle_count <= cycle_count + 8'd1;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    result_valid <= 1'b0;
                    cycle_count <= 8'd0;
                end

                default: begin
                    result_valid <= 1'b0;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Safety check for cycle count
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_count <= 8'd0;
        end else if (cycle_count >= MAX_CYCLES) begin
            cycle_count <= 8'd0;
            state <= IDLE;
        end
    end

endmodule