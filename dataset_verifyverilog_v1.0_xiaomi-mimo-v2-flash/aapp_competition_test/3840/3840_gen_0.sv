module TopModule (
    input clk,
    input rst_n,
    input start,
    input [6:0] n,
    input [9:0] a_1_to_a_n [1:100],
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE      = 3'd0;
    localparam [2:0] CHECK     = 3'd1;
    localparam [2:0] INIT      = 3'd2;
    localparam [2:0] COMPUTE   = 3'd3;
    localparam [2:0] FINISH    = 3'd4;

    // Internal registers and wires
    reg [2:0] state, next_state;
    reg [15:0] moves;
    reg [6:0] i;  // loop counter
    reg [6:0] p;  // parent index
    reg [9:0] buffer [1:100];  // copy of input coins
    reg [9:0] child_max;
    reg [10:0] parent_new_temp;  // Extra bit for signed comparison
    reg [9:0] parent_new;
    reg [2:0] cycle_count;  // For timing constraints

    // Helper wire for max computation
    wire [9:0] max_val;
    assign max_val = (buffer[i] > buffer[i-1]) ? buffer[i] : buffer[i-1];

    // State transition logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'hFFFF;
            done <= 1'b0;
            moves <= 16'd0;
            i <= 7'd0;
            p <= 7'd0;
            child_max <= 10'd0;
            parent_new <= 10'd0;
            cycle_count <= 3'd0;
            // Initialize buffer
            for (int j = 1; j <= 100; j = j + 1) begin
                buffer[j] <= 10'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    result <= 16'hFFFF;
                    moves <= 16'd0;
                    i <= 7'd0;
                    p <= 7'd0;
                    child_max <= 10'd0;
                    parent_new <= 10'd0;
                    cycle_count <= 3'd0;
                    // Maintain buffer values (or clear if needed, but input comes in at start)
                end
                
                CHECK: begin
                    // Check validity: n must be odd and > 1
                    if (n > 7'd1 && n[0] == 1'b1) begin
                        // Valid case: proceed to INIT
                        result <= 16'd0;  // Temporarily 0
                    end else begin
                        // Invalid: n==1 or n even
                        result <= 16'hFFFF;
                        done <= 1'b1;
                        // Will transition to IDLE next cycle via FINISH or directly
                    end
                end
                
                INIT: begin
                    // Copy input to buffer (unpack)
                    // In synthesis, this must be handled carefully. 
                    // Since a_1_to_a_n is an unpacked array input, we need to map it.
                    // For Icarus compatibility and simple logic, we assume direct mapping if possible,
                    // or we handle in a loop.
                    // Note: SystemVerilog allows direct assignment for arrays of same type/size in non-blocking.
                    // To be safe and Icarus compatible, we iterate.
                    for (int j = 1; j <= 100; j = j + 1) begin
                        if (j <= n) begin
                            buffer[j] <= a_1_to_a_n[j];
                        end else begin
                            buffer[j] <= 10'd0;
                        end
                    end
                    i <= n;
                    moves <= 16'd0;
                end
                
                COMPUTE: begin
                    if (i > 7'd3) begin
                        // Check if i is odd (loop condition: step -2, starting from n which is odd)
                        // Since we step by 2, i remains odd.
                        
                        child_max <= max_val;
                        
                        // Add to moves
                        moves <= moves + {6'd0, max_val};
                        
                        // Calculate parent index
                        p <= i >> 1;  // Integer division by 2
                        
                        // Calculate parent_new
                        parent_new_temp <= {1'b0, buffer[i >> 1]} - {1'b0, max_val};
                        
                        // We will update buffer in the next cycle or here depending on timing.
                        // To avoid timing loops, let's calculate and update in next state or combine.
                        // Actually, let's update buffer immediately after calculation.
                        // Parent index p = i/2.
                        
                        // Update buffer for current i
                        buffer[i] <= 10'd0;
                        buffer[i-1] <= 10'd0;
                        
                        // Update parent buffer[p]
                        // parent_new_temp is 11-bit. If MSB is 1, it's negative.
                        if (parent_new_temp[10]) begin
                            buffer[p] <= 10'd0;
                        end else begin
                            buffer[p] <= parent_new_temp[9:0];
                        end
                        
                        i <= i - 7'd2;  // Decrement by 2
                        
                    end else begin
                        // Loop finished (i <= 3)
                        // Add remaining root coins
                        moves <= moves + {6'd0, buffer[1]};
                    end
                end
                
                FINISH: begin
                    done <= 1'b1;
                    if (state == CHECK && (n <= 7'd1 || n[0] == 1'b0)) begin
                        // Already set result to FFFF in CHECK
                    end else begin
                        result <= moves;
                    end
                end
            endcase
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;  // Default stay in current state
        
        case (state)
            IDLE: begin
                if (start) next_state = CHECK;
            end
            
            CHECK: begin
                if (n > 7'd1 && n[0] == 1'b1) begin
                    next_state = INIT;
                end else begin
                    next_state = FINISH;  // Invalid, output -1 immediately
                end
            end
            
            INIT: begin
                next_state = COMPUTE;
            end
            
            COMPUTE: begin
                // We loop in this state until i <= 3
                // Check loop condition: i > 3
                if (i > 7'd3) begin
                    next_state = COMPUTE;  // Stay in compute to process next pair
                end else begin
                    // Loop finished, add root and finish
                    next_state = FINISH;
                end
            end
            
            FINISH: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule