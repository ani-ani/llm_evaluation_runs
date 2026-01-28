module population_count (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] n,
    output reg [3:0] count,
    output reg done
);

    // State declarations
    localparam [1:0] IDLE     = 2'd0;
    localparam [1:0] COUNTING = 2'd1;
    localparam [1:0] DONE     = 2'd2;

    // Internal registers
    reg [1:0] state, next_state;
    reg [7:0] shift_reg;      // Shift register to process bits
    reg [3:0] bit_counter;    // Counts from 0 to 7
    reg [3:0] acc_count;      // Accumulator for set bits
    reg processing_done;      // Flag when 8 bits processed

    // State transition logic (combinational)
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = COUNTING;
            end
            COUNTING: begin
                if (processing_done)
                    next_state = DONE;
            end
            DONE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic and datapath
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers
            state <= IDLE;
            shift_reg <= 8'd0;
            bit_counter <= 4'd0;
            acc_count <= 4'd0;
            count <= 4'd0;
            done <= 1'b0;
            processing_done <= 1'b0;
        end else begin
            // Default assignments
            done <= 1'b0;
            processing_done <= 1'b0;
            state <= next_state;

            case (next_state)
                IDLE: begin
                    // Clear done and prepare for new computation
                    done <= 1'b0;
                    count <= 4'd0;
                    if (start) begin
                        // Load input and initialize counters
                        shift_reg <= n;
                        bit_counter <= 4'd0;
                        acc_count <= 4'd0;
                    end
                end

                COUNTING: begin
                    // Check LSB and add to count if set
                    if (shift_reg[0]) begin
                        acc_count <= acc_count + 4'd1;
                    end
                    // Shift right by 1
                    shift_reg <= {1'b0, shift_reg[7:1]};
                    // Increment bit counter
                    bit_counter <= bit_counter + 4'd1;
                    // Check if 8 bits processed (bit_counter goes 0->7, then 8)
                    if (bit_counter == 4'd7) begin
                        processing_done <= 1'b1;
                    end
                end

                DONE: begin
                    // Latch result and assert done
                    count <= acc_count;
                    done <= 1'b1;
                end

                default: begin
                    state <= IDLE;
                    shift_reg <= 8'd0;
                    bit_counter <= 4'd0;
                    acc_count <= 4'd0;
                    count <= 4'd0;
                    done <= 1'b0;
                    processing_done <= 1'b0;
                end
            endcase
        end
    end

endmodule