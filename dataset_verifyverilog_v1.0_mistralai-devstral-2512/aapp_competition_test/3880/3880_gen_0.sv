module YaroslavSolver(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    input wire [7:0] data_in,
    input wire data_valid,
    output reg [31:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE      = 2'd0;
    localparam [1:0] LOAD      = 2'd1;
    localparam [1:0] CALCULATE = 2'd2;
    localparam [1:0] OUTPUT    = 2'd3;

    // Registers
    reg [1:0] state;
    reg [3:0] n_reg;
    reg [4:0] idx;
    reg [4:0] total_elements;
    reg [4:0] neg_count;
    reg [15:0] min_abs;
    reg [31:0] sum_abs;
    reg [7:0] current_data;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            n_reg <= 4'd0;
            idx <= 5'd0;
            total_elements <= 5'd0;
            neg_count <= 5'd0;
            min_abs <= 16'd0;
            sum_abs <= 32'd0;
            current_data <= 8'd0;
            result <= 32'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= LOAD;
                        n_reg <= n;
                        total_elements <= (n_reg << 1) - 1;
                        idx <= 5'd0;
                        neg_count <= 5'd0;
                        min_abs <= 16'd0;
                        sum_abs <= 32'd0;
                    end
                end

                LOAD: begin
                    if (data_valid) begin
                        current_data <= data_in;
                        // Check if negative
                        if (current_data[7]) begin
                            neg_count <= neg_count + 1;
                        end
                        // Calculate absolute value
                        if (current_data[7]) begin
                            current_data <= -current_data;
                        end
                        // Update sum and min
                        sum_abs <= sum_abs + current_data;
                        if (idx == 0 || current_data < min_abs) begin
                            min_abs <= current_data;
                        end
                        // Increment index
                        idx <= idx + 1;
                        // Check if done loading
                        if (idx == total_elements) begin
                            state <= CALCULATE;
                        end
                    end
                end

                CALCULATE: begin
                    // Determine result based on n and neg_count
                    if (n_reg[0]) begin  // n is odd
                        result <= sum_abs;
                    end else begin  // n is even
                        if (neg_count[0]) begin  // neg_count is odd
                            result <= sum_abs - (min_abs << 1);
                        end else begin  // neg_count is even
                            result <= sum_abs;
                        end
                    end
                    state <= OUTPUT;
                end

                OUTPUT: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule