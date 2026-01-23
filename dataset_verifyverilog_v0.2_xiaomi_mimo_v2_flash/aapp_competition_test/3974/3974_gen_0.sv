module min_people_finder(
    input clk,
    input rst_n,
    input start,
    input [63:0] events,
    input [5:0] length,
    output reg [7:0] result,
    output reg done
);

    // State encoding
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam CALCULATE = 2'b10;
    localparam DONE_STATE = 2'b11;

    reg [1:0] state;
    reg [5:0] count;         // Iteration counter (index of bit to process)
    reg signed [8:0] running; // Running counter, signed to handle negatives properly
    reg signed [8:0] min_val; // Track minimum value
    reg signed [8:0] max_val; // Track maximum value

    always @(posedge clk) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 8'b0;
            done <= 1'b0;
            count <= 6'b0;
            running <= 9'sd0;
            min_val <= 9'sd0;
            max_val <= 9'sd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        state <= PROCESSING;
                        count <= 6'b0;
                        running <= 9'sd0;
                        min_val <= 9'sd0;
                        max_val <= 9'sd0;
                    end
                end

                PROCESSING: begin
                    if (count < length) begin
                        // Process current event
                        // events[0] is the first event (MSB of vector as per prompt, but typically events[0] is LSB in Verilog)
                        // Prompt says: "Bit 0 is the first event (MSB)". 
                        // Wait, usually 'Bit 0' refers to the LSB of the vector index [0].
                        // If Bit 0 is the first event, we process from index 0 upwards.
                        // However, if "MSB" refers to the visual representation, we might need to process from length-1 downwards.
                        // Let's strictly follow "Bit 0 is the first event (MSB)".
                        // Usually bit 0 of a vector is the LSB. 
                        // If it implies bits are packed [63:0] and we start from 63, the user usually writes events[63] is MSB.
                        // Let's assume standard little-endian indexing: events[count] is the event at index 'count'.
                        // But to match "Bit 0 is the first event (MSB)", let's process from the MSB of the valid range.
                        // The valid range is length bits. If length is 64, bits 63..0 are valid.
                        // If length is 4, bits 3..0 are valid.
                        // Let's process events[length - 1 - count] to honor "MSB first" convention often used in packed vectors.
                        
                        if (events[length - 1 - count]) begin
                            running <= running + 1;
                            if (running + 1 > max_val) max_val <= running + 1;
                        end else begin
                            running <= running - 1;
                            if (running - 1 < min_val) min_val <= running - 1;
                        end
                        
                        count <= count + 1;
                    end else begin
                        state <= CALCULATE;
                    end
                end

                CALCULATE: begin
                    // result = max_val - min_val
                    // Both are signed, but result is unsigned [7:0]
                    // Since we track min_val <= 0 and max_val >= 0, difference is non-negative.
                    result <= max_val - min_val; 
                    state <= DONE_STATE;
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    // Wait for reset or next start. 
                    // If start comes while in DONE, we transition back to PROCESSING on next clock edge.
                    if (start) begin
                        done <= 1'b0;
                        count <= 6'b0;
                        running <= 9'sd0;
                        min_val <= 9'sd0;
                        max_val <= 9'sd0;
                        state <= PROCESSING;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule