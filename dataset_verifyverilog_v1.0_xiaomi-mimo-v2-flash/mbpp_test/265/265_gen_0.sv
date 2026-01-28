module array_splitter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [3:0] len,
    input wire [3:0] step,
    input wire [127:0] data_in,
    output reg [1023:0] result_out,
    output reg valid_out
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [3:0] j;          // Input index counter
    reg [1023:0] result_reg;  // Holds the accumulated result
    reg [3:0] captured_len;
    reg [3:0] captured_step;
    reg [4:0] cycle_count; // Max 32 cycles

    // Control signal for computation
    wire compute_done;
    assign compute_done = (j >= captured_len);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_out <= 1'b0;
            result_out <= 1024'd0;
            j <= 4'd0;
            result_reg <= 1024'd0;
            captured_len <= 4'd0;
            captured_step <= 4'd0;
            cycle_count <= 5'd0;
        end else begin
            valid_out <= 1'b0; // Default pulse
            
            case (state)
                IDLE: begin
                    j <= 4'd0;
                    cycle_count <= 5'd0;
                    result_reg <= 1024'd0;
                    if (start) begin
                        captured_len <= len;
                        captured_step <= step;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    cycle_count <= cycle_count + 5'd1;
                    
                    // Check for valid data and within bounds
                    if (j < captured_len) begin
                        // Calculate sub-sequence and position
                        // i = j % step
                        // k = j / step
                        // Since step is max 8, we can use simpler logic
                        // Position in output: (i * 128) + (k * 8)
                        
                        // Extract current byte from data_in
                        // data_in is 128 bits (16 bytes), indexed 0-15
                        // data_in[j*8 +: 8]
                        // For synthesizable indexing, we need to be careful
                        // We will use a loop or explicit extraction logic
                        
                        // Logic: j goes 0,1,2,3... (step-1)
                        // i = j % step (0 to step-1)
                        // k = j / step (0 to 15)
                        
                        // To avoid complex modulo in hardware for variable step,
                        // we simulate the assignment logic.
                        // However, modulo on variable width is tricky. 
                        // Since step <= 8, we can unroll or use a small counter array.
                        // Given constraints (32 cycles max), step is small.
                        
                        // Let's calculate i and k.
                        // Since step is small, we can use a simple if-else cascade or behavior
                        // Note: Synthesis tools handle modulo reasonably well for small constants,
                        // but step is variable. We must implement it explicitly.
                        
                        // Extract byte manually to avoid array slicing issues
                        reg [7:0] current_byte;
                        integer idx;
                        idx = j;
                        current_byte = data_in[idx*8 +: 8];
                        
                        // Calculate i (sub-sequence) and k (position)
                        // i = j % step
                        // k = j / step
                        // Since step <= 8, division by 8 is shift, but step is variable.
                        // We use logic division.
                        
                        // For synthesizable variable division/modulo in a cycle,
                        // it's usually implemented as a multiplier or logic.
                        // Given the small range (0-15), we can use a lookup or simple math.
                        
                        // To be safe and compliant with Icarus Verilog limitations,
                        // we compute i and k using standard operators, as they map to DSPs or logic.
                        
                        reg [3:0] i;
                        reg [3:0] k;
                        
                        i = j % captured_step;
                        k = j / captured_step;
                        
                        // Calculate bit offset in result_reg
                        // offset = (i * 128) + (k * 8)
                        // i is 0-7, k is 0-15
                        // i*128 = i << 7
                        // k*8 = k << 3
                        // Total offset = (i << 7) | (k << 3)
                        // Wait, i and k are 4 bits. i << 7 results in 11 bits.
                        // k << 3 results in 7 bits.
                        // Let's do it in steps to ensure width correctness.
                        
                        // Create offset index
                        // Note: We are writing to result_reg (1024 bits).
                        // result_reg[offset +: 8] = current_byte;
                        
                        // Synthesizable concatenation for bit slicing:
                        // We construct the slice index manually or rely on tools.
                        // For Icarus Verilog compatibility, explicit indexing is safer if static,
                        // but here it's dynamic.
                        // Verilog allows dynamic part select if width is constant.
                        
                        // offset calculation:
                        // offset = (i << 7) + (k << 3)
                        // Let's compute in registers to manage widths.
                        reg [10:0] offset;
                        offset = (i << 7) | (k << 3);
                        
                        // Perform the assignment to result_reg
                        // Note: result_reg is a large register. We can assign to a slice.
                        result_reg[offset +: 8] <= current_byte;
                        
                        j <= j + 4'd1;
                    end
                    
                    // Completion conditions
                    // 1. All elements processed
                    if (compute_done) begin
                        state <= DONE;
                    end
                    // 2. Safety timeout (32 cycles)
                    else if (cycle_count >= 5'd31) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    result_out <= result_reg;
                    valid_out <= 1'b1;
                    state <= IDLE;
                end

                default: begin
                    state <= IDLE;
                end
            endcase
        end
    end
endmodule