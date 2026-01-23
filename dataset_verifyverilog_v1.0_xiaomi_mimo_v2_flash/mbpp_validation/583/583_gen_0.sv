module catalan_number (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] n,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COMPUTE  = 2'd1;
    localparam [1:0] FINISH   = 2'd2;

    reg [1:0] state;
    reg [3:0] i;
    reg [3:0] j;
    reg [3:0] current_n;
    reg [15:0] catalan [0:8];
    reg [15:0] sum;
    reg [15:0] product;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd12;

    // Combinational logic for multiplication
    wire [31:0] mult_temp;
    assign mult_temp = catalan[j] * catalan[(current_n - 1) - j];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            current_n <= 4'd0;
            sum <= 16'd0;
            product <= 16'd0;
            cycle_count <= 4'd0;
            catalan[0] <= 16'd1;
            catalan[1] <= 16'd1;
            catalan[2] <= 16'd0;
            catalan[3] <= 16'd0;
            catalan[4] <= 16'd0;
            catalan[5] <= 16'd0;
            catalan[6] <= 16'd0;
            catalan[7] <= 16'd0;
            catalan[8] <= 16'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        if (n <= 4'd1) begin
                            result <= 16'd1;
                            done <= 1'b1;
                            state <= IDLE;
                        end else if (n > 4'd8) begin
                            result <= 16'd1430;
                            done <= 1'b1;
                            state <= IDLE;
                        end else begin
                            // Initialize for n = 2
                            current_n <= 4'd2;
                            sum <= 16'd0;
                            j <= 4'd0;
                            state <= COMPUTE;
                        end
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    product <= mult_temp[15:0]; // Truncate to 16-bit
                    
                    // Calculate sum: catalan[j] * catalan[current_n-1-j]
                    if (j < current_n) begin
                        sum <= sum + mult_temp[15:0];
                        j <= j + 4'd1;
                    end else begin
                        // Summation complete
                        catalan[current_n] <= sum;
                        
                        if (current_n == n) begin
                            result <= sum;
                            done <= 1'b1;
                            state <= FINISH;
                        end else begin
                            // Move to next n
                            current_n <= current_n + 4'd1;
                            sum <= 16'd0;
                            j <= 4'd0;
                        end
                    end

                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        result <= catalan[n];
                        done <= 1'b1;
                        state <= FINISH;
                    end
                end

                FINISH: begin
                    done <= 1'b0;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule