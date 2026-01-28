module factorial_last3_digits(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [9:0] n,
    output reg [9:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] COMPUTE   = 3'd1;
    localparam [2:0] FINISH    = 3'd2;

    // Internal registers
    reg [2:0] state;
    reg [9:0] current_n;
    reg [15:0] product;
    reg [7:0] count2;
    reg [7:0] count5;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd500;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 10'd0;
            done <= 1'b0;
            current_n <= 10'd0;
            product <= 16'd1;
            count2 <= 8'd0;
            count5 <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= COMPUTE;
                        current_n <= n;
                        product <= 16'd1;
                        count2 <= 8'd0;
                        count5 <= 8'd0;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;

                    // Compute factorial while removing factors of 10
                    if (current_n > 10'd0) begin
                        reg [15:0] temp_product;
                        reg [7:0] temp_count2;
                        reg [7:0] temp_count5;
                        reg [9:0] i;
                        reg [15:0] num;

                        // Process current_n
                        num = current_n;
                        temp_count2 = 8'd0;
                        temp_count5 = 8'd0;

                        // Count factors of 2
                        for (i = 0; i < 10; i = i + 1) begin
                            if (num % 2 == 0) begin
                                temp_count2 = temp_count2 + 8'd1;
                                num = num / 2;
                            end else begin
                                i = 10; // break
                            end
                        end

                        // Count factors of 5
                        num = current_n;
                        for (i = 0; i < 10; i = i + 1) begin
                            if (num % 5 == 0) begin
                                temp_count5 = temp_count5 + 8'd1;
                                num = num / 5;
                            end else begin
                                i = 10; // break
                            end
                        end

                        // Multiply into product (mod 10000)
                        temp_product = product * num;
                        product = temp_product % 16'd10000;
                        count2 = count2 + temp_count2;
                        count5 = count5 + temp_count5;

                        current_n = current_n - 10'd1;
                    end else begin
                        // Final computation
                        reg [15:0] final_product;
                        reg [7:0] diff;
                        reg [15:0] power2;
                        reg [7:0] j;

                        // Compute 2^(count2-count5) mod 1000
                        diff = count2 - count5;
                        power2 = 16'd1;
                        for (j = 0; j < diff; j = j + 1) begin
                            power2 = (power2 * 2) % 16'd1000;
                        end

                        final_product = (product % 16'd1000) * power2;
                        result = final_product % 16'd1000;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule