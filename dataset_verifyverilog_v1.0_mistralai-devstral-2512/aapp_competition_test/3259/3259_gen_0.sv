module aladin_machine(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire op_type,
    input wire [9:0] L,
    input wire [9:0] R,
    input wire [15:0] A,
    input wire [15:0] B,
    output reg [31:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESS = 2'd1;
    localparam [1:0] FINISH = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [9:0] current_index;
    reg [31:0] accumulator;
    reg [15:0] k_value;
    reg [31:0] product;

    // BRAM for array storage (1024 x 16 bits)
    reg [15:0] arr [0:1023];

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_index <= 10'd0;
            accumulator <= 32'd0;
            k_value <= 16'd0;
            product <= 32'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    current_index = L - 10'd1;  // Convert to 0-based
                    accumulator = 32'd0;
                    k_value = 16'd1;
                end else begin
                    next_state = IDLE;
                end
            end

            PROCESS: begin
                if (op_type == 1'b0) begin  // Update operation
                    // Compute value: (k * A) % B
                    product = k_value * A;
                    if (product >= B) begin
                        product = product - B;
                    end
                    arr[current_index] = product[15:0];

                    // Move to next index
                    if (current_index == R - 10'd1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = PROCESS;
                        current_index = current_index + 10'd1;
                        k_value = k_value + 16'd1;
                    end
                end else begin  // Query operation
                    accumulator = accumulator + arr[current_index];

                    // Move to next index
                    if (current_index == R - 10'd1) begin
                        next_state = FINISH;
                    end else begin
                        next_state = PROCESS;
                        current_index = current_index + 10'd1;
                    end
                end
            end

            FINISH: begin
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    result <= 32'd0;
                    done <= 1'b0;
                end

                PROCESS: begin
                    done <= 1'b0;
                end

                FINISH: begin
                    if (op_type == 1'b1) begin  // Query operation
                        result <= accumulator;
                    end
                    done <= 1'b1;
                end

                default: begin
                    result <= 32'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule