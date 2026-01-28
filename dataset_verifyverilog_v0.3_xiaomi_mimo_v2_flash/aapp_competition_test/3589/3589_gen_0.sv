module digit_product_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] L,
    input wire [9:0] R,
    output reg [31:0] count_1,
    output reg [31:0] count_2,
    output reg [31:0] count_3,
    output reg [31:0] count_4,
    output reg [31:0] count_5,
    output reg [31:0] count_6,
    output reg [31:0] count_7,
    output reg [31:0] count_8,
    output reg [31:0] count_9,
    output reg done
);

    // State encoding
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOAD       = 3'd1;
    localparam [2:0] COMPUTE    = 3'd2;
    localparam [2:0] INCREMENT  = 3'd3;
    localparam [2:0] DONE_STATE = 3'd4;

    // Compute sub-states
    localparam [2:0] COMP_INIT       = 3'd0;
    localparam [2:0] COMP_GET_DIGIT  = 3'd1;
    localparam [2:0] COMP_MULTIPLY   = 3'd2;
    localparam [2:0] COMP_CHECK      = 3'd3;

    reg [2:0] state;
    reg [2:0] next_state;
    reg [2:0] compute_state;
    reg [2:0] next_compute_state;

    reg [9:0] current_number;
    reg [9:0] next_current_number;
    reg [15:0] product;
    reg [15:0] next_product;
    reg [9:0] temp;
    reg [9:0] next_temp;
    reg [3:0] digit;
    reg [3:0] next_digit;

    // Combinational logic for digit extraction and multiplication
    wire [3:0] next_digit_wire;
    wire [9:0] next_temp_wire;
    wire [15:0] next_product_wire;

    assign next_temp_wire = (compute_state == COMP_GET_DIGIT) ? (temp / 10) : temp;
    assign next_digit_wire = (compute_state == COMP_GET_DIGIT) ? (temp % 10) : digit;
    assign next_product_wire = (compute_state == COMP_MULTIPLY) ? (product * digit) : product;

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            compute_state <= COMP_INIT;
            done <= 1'b0;
            count_1 <= 32'd0;
            count_2 <= 32'd0;
            count_3 <= 32'd0;
            count_4 <= 32'd0;
            count_5 <= 32'd0;
            count_6 <= 32'd0;
            count_7 <= 32'd0;
            count_8 <= 32'd0;
            count_9 <= 32'd0;
            current_number <= 10'd0;
            product <= 16'd1;
            temp <= 10'd0;
            digit <= 4'd0;
        end else begin
            state <= next_state;
            compute_state <= next_compute_state;
            current_number <= next_current_number;
            product <= next_product;
            temp <= next_temp;
            digit <= next_digit;

            // Update counts in INCREMENT state
            if (state == INCREMENT) begin
                case (product)
                    16'd1: count_1 <= count_1 + 32'd1;
                    16'd2: count_2 <= count_2 + 32'd1;
                    16'd3: count_3 <= count_3 + 32'd1;
                    16'd4: count_4 <= count_4 + 32'd1;
                    16'd5: count_5 <= count_5 + 32'd1;
                    16'd6: count_6 <= count_6 + 32'd1;
                    16'd7: count_7 <= count_7 + 32'd1;
                    16'd8: count_8 <= count_8 + 32'd1;
                    16'd9: count_9 <= count_9 + 32'd1;
                    default: ; // Should not reach here
                endcase
            end
        end
    end

    // Combinational next-state logic
    always @(*) begin
        // Default assignments
        next_state = state;
        next_compute_state = compute_state;
        next_current_number = current_number;
        next_product = product;
        next_temp = temp;
        next_digit = digit;
        
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = LOAD;
                end
            end

            LOAD: begin
                // Initialize all counts to 0
                count_1 = 32'd0;
                count_2 = 32'd0;
                count_3 = 32'd0;
                count_4 = 32'd0;
                count_5 = 32'd0;
                count_6 = 32'd0;
                count_7 = 32'd0;
                count_8 = 32'd0;
                count_9 = 32'd0;
                next_current_number = L;
                next_state = COMPUTE;
                next_compute_state = COMP_INIT;
            end

            COMPUTE: begin
                case (compute_state)
                    COMP_INIT: begin
                        next_temp = current_number;
                        next_product = 16'd1;
                        next_compute_state = COMP_GET_DIGIT;
                    end

                    COMP_GET_DIGIT: begin
                        if (temp == 10'd0) begin
                            next_compute_state = COMP_CHECK;
                        end else begin
                            next_temp = next_temp_wire;
                            next_digit = next_digit_wire;
                            next_compute_state = COMP_MULTIPLY;
                        end
                    end

                    COMP_MULTIPLY: begin
                        if (digit != 4'd0) begin
                            next_product = next_product_wire;
                        end
                        next_compute_state = COMP_GET_DIGIT;
                    end

                    COMP_CHECK: begin
                        if (product < 16'd10) begin
                            next_state = INCREMENT;
                        end else begin
                            next_temp = product;
                            next_product = 16'd1;
                            next_compute_state = COMP_INIT;
                        end
                    end
                endcase
            end

            INCREMENT: begin
                if (current_number >= R) begin
                    next_state = DONE_STATE;
                end else begin
                    next_current_number = current_number + 10'd1;
                    next_state = COMPUTE;
                    next_compute_state = COMP_INIT;
                end
            end

            DONE_STATE: begin
                // done signal handled in sequential block
                if (!start) begin
                    next_state = IDLE;
                end
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Done signal logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            done <= 1'b0;
        end else begin
            if (state == IDLE && start) begin
                done <= 1'b0;
            end else if (state == DONE_STATE) begin
                done <= 1'b1;
            end
        end
    end

endmodule