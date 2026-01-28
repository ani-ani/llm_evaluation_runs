module elementwise_division (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] tuple1 [0:3],
    input wire [7:0] tuple2 [0:3],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH = 2'd2;
    
    reg [1:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;
    localparam [7:0] DIV_CYCLES = 8'd8;
    
    // Internal registers for quotients
    reg [3:0] quot0, quot1, quot2, quot3;
    
    // Division unit control signals
    reg [2:0] div_idx;  // Which element we're currently dividing
    reg [7:0] div_a, div_b;  // Current dividend and divisor
    reg div_start;
    wire [3:0] div_result;
    wire div_done;
    
    // 8-bit to 4-bit division unit
    sequential_divider div (
        .clk(clk),
        .rst_n(rst_n),
        .start(div_start),
        .a(div_a),
        .b(div_b),
        .quotient(div_result),
        .done(div_done)
    );
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            div_idx <= 3'd0;
            div_start <= 1'b0;
            quot0 <= 4'd0;
            quot1 <= 4'd0;
            quot2 <= 4'd0;
            quot3 <= 4'd0;
            div_a <= 8'd0;
            div_b <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    div_idx <= 3'd0;
                    div_start <= 1'b0;
                    if (start) begin
                        state <= COMPUTE;
                        // Load first division
                        div_a <= tuple1[0];
                        div_b <= tuple2[0];
                        div_start <= 1'b1;
                    end
                end
                
                COMPUTE: begin
                    div_start <= 1'b0;
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (div_done) begin
                        // Store result based on index
                        case (div_idx)
                            3'd0: quot0 <= div_result;
                            3'd1: quot1 <= div_result;
                            3'd2: quot2 <= div_result;
                            3'd3: quot3 <= div_result;
                            default: quot0 <= div_result;
                        endcase
                        
                        // Move to next element
                        if (div_idx < 3'd3) begin
                            div_idx <= div_idx + 3'd1;
                            div_a <= tuple1[div_idx + 3'd1];
                            div_b <= tuple2[div_idx + 3'd1];
                            div_start <= 1'b1;
                        end else begin
                            // All divisions complete
                            state <= FINISH;
                        end
                    end
                    
                    // Safety timeout
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Pack results: {quot3, quot2, quot1, quot0}
                    result <= {quot3, quot2, quot1, quot0};
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end

endmodule

// Sequential 8-bit to 4-bit division module
module sequential_divider (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] a,
    input wire [7:0] b,
    output reg [3:0] quotient,
    output reg done
);

    localparam [2:0] DIV_IDLE = 3'd0;
    localparam [2:0] DIV_SHIFT = 3'd1;
    localparam [2:0] DIV_SUB = 3'd2;
    localparam [2:0] DIV_STORE = 3'd3;
    localparam [2:0] DIV_FINISHED = 3'd4;
    
    reg [2:0] div_state;
    reg [3:0] quotient_reg;
    reg [4:0] remainder;
    reg [2:0] bit_count;
    reg [7:0] divisor_reg;
    reg [11:0] dividend_ext;  // 12-bit: 8-bit dividend + 4-bit quotient space
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            div_state <= DIV_IDLE;
            quotient <= 4'd0;
            done <= 1'b0;
            quotient_reg <= 4'd0;
            remainder <= 5'd0;
            bit_count <= 3'd0;
            divisor_reg <= 8'd0;
            dividend_ext <= 12'd0;
        end else begin
            case (div_state)
                DIV_IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Initialize: dividend in upper bits, divisor stored
                        dividend_ext <= {4'd0, a};  // Clear quotient bits
                        divisor_reg <= b;
                        remainder <= 5'd0;
                        quotient_reg <= 4'd0;
                        bit_count <= 3'd7;  // Need 8 cycles for 8-bit dividend
                        div_state <= DIV_SHIFT;
                    end
                end
                
                DIV_SHIFT: begin
                    // Shift dividend left
                    dividend_ext <= dividend_ext << 1;
                    bit_count <= bit_count - 3'd1;
                    div_state <= DIV_SUB;
                end
                
                DIV_SUB: begin
                    // Compare current remainder (5 bits) with divisor
                    if ({dividend_ext[10:6], dividend_ext[11]} >= {1'b0, divisor_reg[3:0]}) begin
                        // Partial division for lower nibble
                        remainder <= dividend_ext[10:6] - {1'b0, divisor_reg[3:0]};
                        quotient_reg[0] <= 1'b1;
                    end else begin
                        quotient_reg[0] <= 1'b0;
                    end
                    div_state <= DIV_STORE;
                end
                
                DIV_STORE: begin
                    if (bit_count == 3'd0) begin
                        div_state <= DIV_FINISHED;
                    end else begin
                        div_state <= DIV_SHIFT;
                    end
                    quotient_reg[3:0] <= quotient_reg[2:0];
                end
                
                DIV_FINISHED: begin
                    // Simple unsigned division: a / b
                    // For the full example, we'll do straightforward integer division
                    // Using hardware division logic for 8-bit to 4-bit quotient
                    quotient <= (a >= {4'd0, divisor_reg}) ? a[7:4] : a[7:4];
                    // Simplified: just take upper nibble for this example
                    // In real implementation, full division would be needed
                    quotient <= a / b;  // Combinatorial for simplicity
                    done <= 1'b1;
                    div_state <= DIV_IDLE;
                end
                
                default: div_state <= DIV_IDLE;
            endcase
        end
    end
    
    // Combinatorial fallback for completion
    always @(*) begin
        if (div_state == DIV_FINISHED && done) begin
            quotient = a / b;
        end
    end

endmodule