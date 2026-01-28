module digit_sum_calculator(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] base,
    input wire [3:0] power,
    output reg [7:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE   = 2'd0;
    localparam [1:0] POWER  = 2'd1;
    localparam [1:0] DIGIT  = 2'd2;
    localparam [1:0] DONE   = 2'd3;

    // Internal registers
    reg [1:0] state;
    reg [31:0] value;      // Holds base^power
    reg [31:0] temp;       // Temporary for digit extraction
    reg [7:0] digit_sum;   // Accumulates sum of digits
    reg [3:0] mult_count;  // Counter for multiplication loop
    reg [3:0] div_count;   // Counter for division loop
    reg [7:0] cycle_count; // Prevent infinite loops
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            value <= 32'd0;
            temp <= 32'd0;
            digit_sum <= 8'd0;
            mult_count <= 4'd0;
            div_count <= 4'd0;
            cycle_count <= 8'd0;
            result <= 8'd0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= POWER;
                        // Handle special cases
                        if (base == 4'd0) begin
                            if (power == 4'd0) begin
                                value <= 32'd1;  // 0^0 = 1
                            end else begin
                                value <= 32'd0;  // 0^power = 0
                            end
                        end else if (power == 4'd0) begin
                            value <= 32'd1;  // base^0 = 1
                        end else begin
                            value <= base;   // base^1 = base
                            mult_count <= power - 4'd1;  // Remaining multiplies
                        end
                    end
                end

                POWER: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (mult_count > 4'd0) begin
                        value <= value * base;
                        mult_count <= mult_count - 4'd1;
                    end else begin
                        temp <= value;
                        state <= DIGIT;
                    end
                end

                DIGIT: begin
                    cycle_count <= cycle_count + 8'd1;
                    if (temp == 32'd0) begin
                        result <= digit_sum;
                        state <= DONE;
                    end else begin
                        // Extract least significant digit
                        div_count <= 4'd0;
                        while (div_count < 4'd10 && temp >= 10) begin
                            temp <= temp - 32'd10;
                            div_count <= div_count + 4'd1;
                        end
                        digit_sum <= digit_sum + div_count;
                        // Remove least significant digit
                        div_count <= 4'd0;
                        while (div_count < 4'd10 && temp >= 10) begin
                            temp <= temp - 32'd10;
                            div_count <= div_count + 4'd1;
                        end
                        temp <= temp / 10;
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