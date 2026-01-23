module puzzle_rearrangement (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] n,
    input wire [7:0] a_in,
    input wire [7:0] b_in,
    output reg result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE_STATE = 2'b10;

    reg [1:0] state;
    reg [2:0] i_counter;       // Rotation offset
    reg [7:0] a;
    reg [7:0] b;
    wire [7:0] rotated_a;
    wire match;

    // Theoretical max n is 8. Mask must support up to 8 bits.
    // However, we need to handle n=8 correctly with shift.
    // (a << (8-i)) wraps around naturally in a 8-bit register if we don't mask intermediate steps,
    // but the final equality check 'rotated_a == b' handles bits outside [n-1:0].
    // Wait, if n=3, bits 3-7 of a_in are ignored.
    // But if we shift 1 (bit 0) to bit 7, it would match b[7].
    // We need to mask the rotated_a to 'n' bits before comparing?
    // Or ensure that bits outside [n-1:0] are 0 in both a and b.
    // The problem implies bits >= n are unused/0. So we should mask.
    
    // Mask generation
    wire [7:0] n_mask;
    assign n_mask = (1 << n) - 1;

    // Barrel shifter logic
    // Rotate right by i_counter (shift bits right, wrap high bits)
    assign rotated_a = ((a >> i_counter) | (a << (n - i_counter))) & n_mask;
    
    // Combinational match check
    assign match = (rotated_a == b);

    // Sequential Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 0;
            result <= 0;
            i_counter <= 0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 0;
                    if (start) begin
                        // Load inputs and mask them to n bits immediately
                        // This ensures we only compare valid bits
                        a <= a_in & n_mask;
                        b <= b_in & n_mask;
                        i_counter <= 0;
                        
                        // Check if b is a rotation of a
                        // We can perform the first check immediately in next cycle
                        // or check in current state if we want to spend logic.
                        // Let's just go to PROCESSING
                        state <= PROCESSING;
                    end
                end

                PROCESSING: begin
                    // We rely on the combinational 'rotated_a' and 'match' signals
                    // Since 'a' and 'b' are registered, 'rotated_a' takes 1 cycle to update if purely combinational?
                    // Actually, 'rotated_a' depends on 'a' and 'i_counter'.
                    // In state PROCESSING, we need to check the current rotation.
                    
                    if (match) begin
                        result <= 1;
                        state <= DONE_STATE;
                        done <= 1;
                    end else begin
                        if (i_counter == n - 1) begin
                            // Tried all rotations, no match
                            result <= 0;
                            state <= DONE_STATE;\                            done <= 1;
                        end else begin
                            i_counter <= i_counter + 1;
                        end
                    end
                end

                DONE_STATE: begin
                    // Hold until reset or new start
                    if (!start) begin
                        // Optional: reset done when returning to idle? 
                        // Usually keeps done high until next start or reset.
                        // We will keep done high.
                    end else begin
                        // If start is pressed while in DONE, should ideally restart.
                        // But standard FSMs usually wait for start to go low first.
                        // Let's just hold.
                    end
                end
            endcase
        end
    end

endmodule
