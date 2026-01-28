module max_subarray_sum(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [63:0] a,
    input wire [3:0] n,
    input wire [4:0] k,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] FINISH  = 2'd2;
    
    // Registers
    reg [1:0] state;
    reg [7:0] loop_counter;
    reg signed [15:0] max_so_far;
    reg signed [15:0] max_ending_here;
    reg [7:0] total_elements;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            loop_counter <= 8'd0;
            max_so_far <= 16'd0;
            max_ending_here <= 16'd0;
            total_elements <= 8'd0;
            cycle_count <= 8'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        total_elements <= n * k;
                        state <= COMPUTE;
                    end
                end
                
                COMPUTE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Calculate current value from array
                    reg [7:0] index;
                    reg signed [7:0] val;
                    index = loop_counter % n;
                    val = a[(index * 8) +: 8];
                    
                    // Kadane's algorithm update
                    if (max_ending_here + val > val) begin
                        max_ending_here <= max_ending_here + val;
                    end else begin
                        max_ending_here <= val;
                    end
                    
                    if (max_so_far < max_ending_here) begin
                        max_so_far <= max_ending_here;
                    end
                    
                    // Increment loop counter
                    loop_counter <= loop_counter + 8'd1;
                    
                    // Check completion
                    if (loop_counter == total_elements || cycle_count >= MAX_CYCLES) begin
                        state <= FINISH;
                    end
                end
                
                FINISH: begin
                    result <= max_so_far;
                    done <= 1'b1;
                    state <= IDLE;
                end
                
                default: state <= IDLE;
            endcase
        end
    end
endmodule