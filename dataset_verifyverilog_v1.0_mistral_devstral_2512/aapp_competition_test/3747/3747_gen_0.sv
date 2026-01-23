module count_bulbasaurs(
    input clk,
    input rst_n,
    input start,
    input [7:0] char_array [0:15],
    input [3:0] valid_length,
    output reg [3:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COUNT   = 2'd1;
    localparam [1:0] COMPUTE = 2'd2;
    localparam [1:0] FINISH  = 2'd3;
    
    reg [1:0] state;
    reg [3:0] cycle_count;
    localparam [3:0] MAX_CYCLES = 4'd20;

    // Character counters
    reg [3:0] count_B;
    reg [3:0] count_u;
    reg [3:0] count_l;
    reg [3:0] count_b;
    reg [3:0] count_a;
    reg [3:0] count_s;
    reg [3:0] count_r;

    // Index for character array
    reg [3:0] index;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            cycle_count <= 4'd0;
            
            // Initialize all counters
            count_B <= 4'd0;
            count_u <= 4'd0;
            count_l <= 4'd0;
            count_b <= 4'd0;
            count_a <= 4'd0;
            count_s <= 4'd0;
            count_r <= 4'd0;
            index <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 4'd0;
                    if (start) begin
                        state <= COUNT;
                        index <= 4'd0;
                        
                        // Reset counters
                        count_B <= 4'd0;
                        count_u <= 4'd0;
                        count_l <= 4'd0;
                        count_b <= 4'd0;
                        count_a <= 4'd0;
                        count_s <= 4'd0;
                        count_r <= 4'd0;
                    end
                end
                
                COUNT: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Count characters
                    if (index < valid_length) begin
                        case (char_array[index])
                            8'd66: count_B <= count_B + 4'd1;  // 'B'
                            8'd85: count_u <= count_u + 4'd1;  // 'u'
                            8'd76: count_l <= count_l + 4'd1;  // 'l'
                            8'd98: count_b <= count_b + 4'd1;  // 'b'
                            8'd65: count_a <= count_a + 4'd1;  // 'a'
                            8'd83: count_s <= count_s + 4'd1;  // 's'
                            8'd82: count_r <= count_r + 4'd1;  // 'r'
                            default: ;
                        endcase
                        
                        index <= index + 4'd1;
                    end else begin
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 4'd1;
                    
                    // Compute minimum of: count_B, count_u//2, count_l, count_b, count_a//2, count_s, count_r
                    reg [3:0] min_val;
                    
                    // Initialize with first value
                    min_val = count_B;
                    
                    // Compare with count_u//2
                    if (count_u / 4'd2 < min_val) begin
                        min_val = count_u / 4'd2;
                    end
                    
                    // Compare with count_l
                    if (count_l < min_val) begin
                        min_val = count_l;
                    end
                    
                    // Compare with count_b
                    if (count_b < min_val) begin
                        min_val = count_b;
                    end
                    
                    // Compare with count_a//2
                    if (count_a / 4'd2 < min_val) begin
                        min_val = count_a / 4'd2;
                    end
                    
                    // Compare with count_s
                    if (count_s < min_val) begin
                        min_val = count_s;
                    end
                    
                    // Compare with count_r
                    if (count_r < min_val) begin
                        min_val = count_r;
                    end
                    
                    result <= min_val;
                    state <= FINISH;
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