module CircularTraversal(
    input clk,
    input rst_n,
    input start,
    input [5:0] n,
    input [9:0] k,
    input [8:0] a,
    input [8:0] b,
    output reg [31:0] result_min,
    output reg [31:0] result_max,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] COMPUTE = 3'd1;
    localparam [2:0] FINISH = 3'd2;
    
    // Internal registers
    reg [2:0] state;
    reg [5:0] i;
    reg [5:0] j;
    reg [14:0] C;
    reg [14:0] s_offset;
    reg [14:0] p_offset;
    reg [14:0] L;
    reg [14:0] g;
    reg [31:0] stops;
    reg [31:0] min_stops;
    reg [31:0] max_stops;
    reg [15:0] cycle_count;
    localparam [15:0] MAX_CYCLES = 16'd10000;

    // GCD computation registers
    reg [14:0] gcd_a;
    reg [14:0] gcd_b;
    reg [14:0] gcd_temp;

    // Division computation registers
    reg [14:0] dividend;
    reg [14:0] divisor;
    reg [14:0] quotient;
    reg [14:0] remainder;
    reg [4:0] div_bit;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            i <= 6'd0;
            j <= 6'd0;
            C <= 15'd0;
            s_offset <= 15'd0;
            p_offset <= 15'd0;
            L <= 15'd0;
            g <= 15'd0;
            stops <= 32'd0;
            min_stops <= 32'd4294967295; // Initialize to max value
            max_stops <= 32'd0;
            result_min <= 32'd0;
            result_max <= 32'd0;
            done <= 1'b0;
            cycle_count <= 16'd0;
            
            gcd_a <= 15'd0;
            gcd_b <= 15'd0;
            gcd_temp <= 15'd0;
            
            dividend <= 15'd0;
            divisor <= 15'd0;
            quotient <= 15'd0;
            remainder <= 15'd0;
            div_bit <= 5'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 16'd0;
                    if (start) begin
                        state <= COMPUTE;
                        C <= n * k;
                        i <= 6'd0;
                        j <= 6'd0;
                        min_stops <= 32'd4294967295;
                        max_stops <= 32'd0;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 16'd1;
                    
                    // Iterate over all combinations of i and j
                    if (i < n) begin
                        if (j < 4) begin
                            // Calculate s_offset and p_offset based on j
                            case (j)
                                4'd0: begin // +a, +b
                                    s_offset <= (i * k) + a;
                                    p_offset <= (i * k) + b;
                                end
                                4'd1: begin // +a, -b
                                    s_offset <= (i * k) + a;
                                    p_offset <= (i * k) - b;
                                end
                                4'd2: begin // -a, +b
                                    s_offset <= (i * k) - a;
                                    p_offset <= (i * k) + b;
                                end
                                4'd3: begin // -a, -b
                                    s_offset <= (i * k) - a;
                                    p_offset <= (i * k) - b;
                                end
                            endcase
                            
                            // Compute L = (p_offset - s_offset) mod C
                            if (p_offset >= s_offset) begin
                                L <= p_offset - s_offset;
                            end else begin
                                L <= C + p_offset - s_offset;
                            end
                            
                            // Skip L=0
                            if (L != 15'd0) begin
                                // Compute GCD(C, L)
                                gcd_a <= C;
                                gcd_b <= L;
                                
                                // Euclidean algorithm
                                while (gcd_b != 15'd0) begin
                                    gcd_temp <= gcd_a % gcd_b;
                                    gcd_a <= gcd_b;
                                    gcd_b <= gcd_temp;
                                end
                                g <= gcd_a;
                                
                                // Compute stops = C / g
                                dividend <= C;
                                divisor <= g;
                                quotient <= 15'd0;
                                remainder <= 15'd0;
                                
                                // Division algorithm
                                for (div_bit = 14; div_bit >= 0; div_bit = div_bit - 1) begin
                                    remainder <= {remainder[13:0], dividend[14]};
                                    dividend <= {dividend[13:0], 1'b0};
                                    
                                    if (remainder >= divisor) begin
                                        remainder <= remainder - divisor;
                                        dividend[0] <= 1'b1;
                                    end else begin
                                        dividend[0] <= 1'b0;
                                    end
                                end
                                quotient <= dividend;
                                stops <= quotient;
                                
                                // Update min and max
                                if (stops < min_stops) begin
                                    min_stops <= stops;
                                end
                                if (stops > max_stops) begin
                                    max_stops <= stops;
                                end
                            end
                            
                            j <= j + 6'd1;
                        end else begin
                            j <= 6'd0;
                            i <= i + 6'd1;
                        end
                    end else begin
                        state <= FINISH;
                    end
                    
                    // Safety check for max cycles
                    if (cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result_min <= min_stops;
                    result_max <= max_stops;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule