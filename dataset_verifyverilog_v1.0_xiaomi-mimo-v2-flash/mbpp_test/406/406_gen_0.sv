module parity_checker (
    input clk,
    input rst_n,
    input start,
    input [15:0] num,
    output reg parity,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] COMPUTE = 2'd1;
    localparam [1:0] DONE = 2'd2;

    // Internal registers
    reg [1:0] state;
    reg [15:0] shift_reg;
    reg xor_accum;
    reg [3:0] counter;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Initialize all registers
            state <= IDLE;
            shift_reg <= 16'd0;
            xor_accum <= 1'b0;
            counter <= 4'd0;
            parity <= 1'b0;
            done <= 1'b0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        // Load num into shift register
                        shift_reg <= num;
                        // Initialize XOR accumulator with LSB of num
                        xor_accum <= num[0];
                        // Initialize counter for 15 iterations
                        counter <= 4'd0;
                        state <= COMPUTE;
                    end
                end

                COMPUTE: begin
                    // Shift right by 1
                    shift_reg <= {1'b0, shift_reg[15:1]};
                    // XOR current LSB (bit 1 of old value) with accumulator
                    xor_accum <= xor_accum ^ shift_reg[1];
                    // Increment counter
                    counter <= counter + 4'd1;
                    
                    // Check for completion (after 15 iterations)
                    if (counter == 4'd14) begin
                        state <= DONE;
                    end
                end

                DONE: begin
                    // Set parity result
                    parity <= xor_accum;
                    // Assert done pulse
                    done <= 1'b1;
                    // Return to IDLE
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule