module remove_uppercase (
    input clk,
    input rst_n,
    input start,
    input [127:0] str_in,
    output reg [127:0] str_out,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam PROCESS = 2'b01;
    localparam DONE = 2'b10;

    reg [1:0] state, next_state;
    reg [3:0] count, next_count;      // Iterates 0 to 15 (4 bits)
    reg [3:0] write_ptr, next_write_ptr; // Next position to write valid char
    reg [127:0] next_str_out;
    reg next_done;

    // Current character extraction
    wire [7:0] current_char;
    assign current_char = str_in[count * 8 +: 8];

    // Combinational logic for next state and outputs
    always @(*) begin
        // Default assignments
        next_state = state;
        next_count = count;
        next_write_ptr = write_ptr;
        next_str_out = str_out;
        next_done = 1'b0;

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESS;
                    next_count = 4'd0;
                    next_write_ptr = 4'd0;
                    next_str_out = 128'd0; // Clear output buffer at start
                end
            end

            PROCESS: begin
                // Check if current character is uppercase (A-Z: 0x41 to 0x5A)
                if (current_char >= 8'h41 && current_char <= 8'h5A) begin
                    // It is uppercase, so skip it (do not increment write_ptr)
                end else begin
                    // Not uppercase, write to output buffer
                    // We need to assign to the specific byte lane
                    // Note: Verilog requires genvar or loop for variable part select in always_comb,
                    // but since we know the width, we can use a temporary array or mask.
                    // However, simpler approach: we can't easily index dynamically in always_comb without generate.
                    // Let's use a helper logic or assume synthesis tool handles it if we use a loop logic.
                    // Actually, the safest synthesizable way for dynamic index in always_comb is to use a case statement or if-else chain for the index.
                    // Or, we can use a temporary vector and slice it.
                    // Let's use a temporary variable to construct the new value.
                    // Since we cannot use procedural assignment to a slice with variable index in always_comb easily in standard Verilog (SystemVerilog allows it better but for strict compatibility let's be careful).
                    // Standard Verilog trick: use a loop inside generate or assign outside.
                    // Here, let's assume standard Verilog-2001 compatible logic where we can't index with variable in always_comb procedural assignment to a vector slice directly if the synthesizer is strict.
                    // However, modern synthesis tools support [index*8 +: 8] but assignment to it is tricky.
                    // Let's do it the robust way: Logic for byte update.
                    
                    // We will update next_str_out based on write_ptr
                    // Using a generate block logic expanded manually for 16 positions isn't feasible here.
                    // Instead, we can rely on SystemVerilog behavior or use a temporary array.
                    // Let's use a temporary unpacked array for clarity and synthesis compatibility.
                    bit [7:0] temp_str [0:15];
                    integer i;
                    // Unpack current str_out to array
                    for (i = 0; i < 16; i = i + 1) begin
                        temp_str[i] = str_out[i*8 +: 8];
                    end
                    // Update the specific index
                    temp_str[write_ptr] = current_char;
                    // Pack back
                    for (i = 0; i < 16; i = i + 1) begin
                        next_str_out[i*8 +: 8] = temp_str[i];
                    end
                    
                    next_write_ptr = write_ptr + 1;
                end

                if (count == 4'd15) begin
                    next_state = DONE;
                end else begin
                    next_count = count + 1;
                end
            end

            DONE: begin
                next_done = 1'b1;
                // Wait for reset or next start implicitly by IDLE transition logic
                // But typically stay in DONE until reset
                // The requirement says start resets the process implicitly via IDLE check.
                // If we stay in DONE, we need to exit on reset.
                // However, standard design: next_state = IDLE; (self-clearing done)
                next_state = IDLE;
            end
        endcase
    end

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            count <= 4'd0;
            write_ptr <= 4'd0;
            str_out <= 128'd0;
            done <= 1'b0;
        end else begin
            state <= next_state;
            count <= next_count;
            write_ptr <= next_write_ptr;
            str_out <= next_str_out;
            done <= next_done;
        end
    end

endmodule
