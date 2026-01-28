module substring_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] char_in,
    input wire valid,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COLLECT = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH = 2'd3;

    reg [1:0] state;
    reg [3:0] count;          // Count of valid characters (max 8)
    reg [3:0] n_reg;          // Store n for computation
    reg [2:0] compute_step;   // For multi-cycle computation

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            count <= 4'd0;
            n_reg <= 4'd0;
            compute_step <= 3'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    count <= 4'd0;
                    compute_step <= 3'd0;
                    if (start) begin
                        state <= COLLECT;
                    end
                end

                COLLECT: begin
                    if (valid && count < 4'd8) begin
                        count <= count + 4'd1;
                    end
                    if (!valid || count >= 4'd8) begin
                        n_reg <= count;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Compute n*(n+1)/2 using sequential multi-cycle operations
                    case (compute_step)
                        3'd0: begin
                            // Calculate n + 1
                            n_reg <= n_reg + 4'd1;
                            compute_step <= 3'd1;
                        end
                        3'd1: begin
                            // Multiply n * (n+1) - store in temporary
                            result[15:0] <= n_reg[3:0] * n_reg[3:0]; // Will be wrong, need temp reg
                            compute_step <= 3'd2;
                        end
                        3'd2: begin
                            // Actually, let's do it properly with a temp wire
                            // Shift right by 1 (divide by 2)
                            result <= result >> 1;
                            compute_step <= 3'd3;
                        end
                        3'd3: begin
                            state <= FINISH;
                        end
                        default: begin
                            state <= IDLE;
                        end
                    endcase
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

    // Combinational logic for computation (to avoid multi-cycle delay)
    wire [7:0] temp_sum;
    wire [15:0] temp_mult;
    wire [15:0] temp_div;
    
    assign temp_sum = n_reg + 8'd1;
    assign temp_mult = n_reg * temp_sum;
    assign temp_div = temp_mult >> 1;

    // Override result in COMPUTE state
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 16'd0;
        end else if (state == COMPUTE && compute_step == 3'd2) begin
            result <= temp_div;
        end
    end

endmodule