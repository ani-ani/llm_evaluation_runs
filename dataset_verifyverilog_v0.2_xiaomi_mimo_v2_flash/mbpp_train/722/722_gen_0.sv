module student_filter (
    input clk,
    input rst_n,
    input start,
    input [15:0] min_height,
    input [15:0] min_weight,
    input [2:0] student_count,
    input [63:0] student0_name,
    input [31:0] student0_height,
    input [31:0] student0_weight,
    input student0_valid,
    input [63:0] student1_name,
    input [31:0] student1_height,
    input [31:0] student1_weight,
    input student1_valid,
    input [63:0] student2_name,
    input [31:0] student2_height,
    input [31:0] student2_weight,
    input student2_valid,
    input [63:0] student3_name,
    input [31:0] student3_height,
    input [31:0] student3_weight,
    input student3_valid,
    output reg [2:0] result_count,
    output reg [63:0] result_name_0,
    output reg [63:0] result_name_1,
    output reg [63:0] result_name_2,
    output reg [63:0] result_name_3,
    output reg done
);

    // State encoding
    localparam IDLE = 3'b000;
    localparam LOAD_0 = 3'b001;
    localparam LOAD_1 = 3'b010;
    localparam LOAD_2 = 3'b011;
    localparam LOAD_3 = 3'b100;
    localparam DONE = 3'b101;

    reg [2:0] state;
    reg [2:0] next_state;

    // Internal signals for comparison
    wire match_0;
    wire match_1;
    wire match_2;
    wire match_3;

    // Comparators: Q16.16 format uses lower 16 bits for fractional part
    // Inputs are 16-bit (min_height/min_weight) but students have 32-bit values.
    // Specification says: "Height/weight values are integers representing (value * 65536)"
    // And "Compare student.height >= min_height AND student.weight >= min_weight"
    // Assuming min_height/min_weight are Q16.16 (16 fractional bits), padded to 32 bits if necessary?
    // Wait, inputs are [15:0]. Specification says "Use Q16.16 fixed-point format for all measurements".
    // But inputs are 16 bits. Usually Q16.16 is 32 bits. 
    // Let's assume the input min_height/min_weight are the integer representation of the threshold.
    // i.e., min_height is already shifted left by 16.
    // But inputs are [15:0]. This implies the threshold is a 16-bit integer value.
    // However, student height is [31:0].
    // "Compare student.height >= min_height"
    // If min_height is 16 bits, and student height is 32 bits (Q16.16), we likely need to zero-extend min_height to 32 bits.
    // OR, the user meant min_height is Q0.16 or Q8.8? No, spec says "Use Q16.16 fixed-point format for all measurements".
    // Input is [15:0]. This is ambiguous. 
    // Often in such problems, a 16-bit input threshold is compared against the lower 16 bits of the 32-bit value if it was a Q0.16 format,
    // OR the 16-bit input represents the Q16.0 part, and we compare with the upper 16 bits of the student's Q16.16 value.
    // BUT, the spec explicitly says "Q16.16 fixed-point format".
    // Let's look at: "Height/weight values are integers representing (value * 65536)". This implies student values are 32-bit.
    // And "input [15:0] min_height". 
    // If min_height is 16 bits, it likely represents the integer part (16 bits) with 0 fractional bits, 
    // or it represents Q0.16 (0 integer, 16 fractional).
    // BUT, the comparison logic is "student.height >= min_height".
    // If min_height is treated as Q16.16 (padded to 32 bits), it should be {min_height, 16'b0}.
    // If min_height is treated as Q0.16, it should be {16'b0, min_height}.
    // Given typical fixed-point filter problems, thresholds are usually given as 16-bit values meant to be scaled.
    // However, "Q16.16 fixed-point format" for the student data means 32 bits.
    // The most standard interpretation when mixing widths in this context (without explicit instruction) is that the 16-bit input is the upper 16 bits (integer part) of the threshold.
    // Or, simpler: The problem statement "input [15:0] min_height" might be a mistake for [31:0], but we must stick to [15:0].
    // Let's assume the 16-bit input is the value to be compared with the *integer* part of the student data, or we extend it.
    // Actually, looking at "Compare student.height >= min_height", if student.height is Q16.16 (32 bits) and min_height is [15:0], 
    // we should probably extend min_height to 32 bits. 
    // Given "Q16.16 fixed-point format for all measurements", the most logical extension for a 16-bit threshold to 32-bit is {min_height, 16'b0}.
    // This treats the input threshold as the integer part of a Q16.16 number.
    // Let's stick with extending the input to the full 32-bit width for comparison. 
    // i.e., extend_min_height = {min_height, 16'b0}.
    // Wait, what if the threshold is small? The input [15:0] covers 0 to 65535.
    // If the student height is Q16.16, a height of 1.5 is represented as 1.5 * 65536 = 98304 (0x00018000).
    // If I input min_height = 1, and extend to {1, 0}, I get 65536. 
    // This effectively compares the integer part. 
    // Let's assume the inputs are simply the 16-bit integer thresholds, and we shift them to compare with Q16.16.
    // Or, the problem implies the inputs are already in the correct units and I should treat the 16-bit input as the upper 16 bits of a 32-bit value.
    // Let's go with: 
    wire [31:0] ext_min_height = {min_height, 16'h0000};
    wire [31:0] ext_min_weight = {min_weight, 16'h0000};
    
    // Actually, re-reading: "Height/weight values are integers representing (value * 65536)".
    // This refers to student0_height, etc.
    // It does NOT explicitly state how min_height is represented.
    // However, to make the comparison valid between [31:0] and [15:0], extension is required.
    // The safest bet for hardware synthesis where strict width matching is expected is that the input 
    // is the value * 65536 as well, but truncated to 16 bits? Unlikely.
    // Let's assume the inputs are the threshold values *before* scaling.
    // i.e., min_height is an integer (e.g. 180).
    // In that case, we need to shift left by 16: ext_min_height = {min_height, 16'b0}.
    // This is the standard behavior for Q16.16 processing with integer inputs.

    assign match_0 = (student0_height >= ext_min_height) && (student0_weight >= ext_min_weight) && student0_valid;
    assign match_1 = (student1_height >= ext_min_height) && (student1_weight >= ext_min_weight) && student1_valid;
    assign match_2 = (student2_height >= ext_min_height) && (student2_weight >= ext_min_weight) && student2_valid;
    assign match_3 = (student3_height >= ext_min_height) && (student3_weight >= ext_min_weight) && student3_valid;

    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start && student_count != 0)
                    next_state = LOAD_0;
                else if (start && student_count == 0)
                    next_state = DONE; // Handle 0 students case immediately (or load->done?)
                                        // Spec says LOAD_0...LOAD_3 then DONE.
                                        // If student_count is 0, we might skip processing.
                                        // But to keep latency consistent, we might go to DONE directly.
                                        // Let's go to DONE directly if count is 0.
                else
                    next_state = IDLE;
            end
            LOAD_0: begin
                if (student_count > 1)
                    next_state = LOAD_1;
                else
                    next_state = DONE;
            end
            LOAD_1: begin
                if (student_count > 2)
                    next_state = LOAD_2;
                else
                    next_state = DONE;
            end
            LOAD_2: begin
                if (student_count > 3)
                    next_state = LOAD_3;
                else
                    next_state = DONE;
            end
            LOAD_3: begin
                next_state = DONE;
            end
            DONE: begin
                // Hold done for 1 cycle, then return to IDLE when start goes low?
                // Or wait for start? 
                // "Latency: 6 clock cycles after start".
                // If we stay in DONE, it's 1 cycle. 
                // The pipeline implies sequential processing.
                // IDLE->LOAD0->LOAD1->LOAD2->LOAD3->DONE = 5 transitions. 
                // If latency is 6 cycles, maybe IDLE(1) + LOADs(4) + DONE(1) = 6?
                // Or maybe there is a delay in the comparison logic.
                // Let's assume one cycle per state, plus IDLE wait.
                // If start is high, we transition. 
                // To meet "Latency: 6 clock cycles", maybe we stay in DONE for 2 cycles?
                // Or the transition happens immediately. 
                // Let's just go back to IDLE. The controller will see done=1.
                // Usually, "done" goes high for one cycle.
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result_count <= 0;
            result_name_0 <= 0;
            result_name_1 <= 0;
            result_name_2 <= 0;
            result_name_3 <= 0;
            done <= 0;
        end else begin
            // Default assignments
            done <= 0;
            
            case (next_state)
                IDLE: begin
                    result_count <= 0;
                    result_name_0 <= 0;
                    result_name_1 <= 0;
                    result_name_2 <= 0;
                    result_name_3 <= 0;
                    done <= 0;
                end
                LOAD_0: begin
                    // Pipeline delay logic:
                    // In cycle 1 (LOAD_0), we process student 0.
                    // Result 0 is stored here.
                    if (match_0) begin
                        result_name_0 <= student0_name;
                        result_count <= 1;
                    end else begin
                        result_count <= 0;
                    end
                    // We don't clear previous results here because IDLE did it.
                    // But we need to be careful if we are not matching.
                    // Actually, result_count is cumulative.
                end
                LOAD_1: begin
                    if (match_1) begin
                        result_name_1 <= student1_name;
                        result_count <= result_count + 1;
                    end
                    // Keep previous results
                end
                LOAD_2: begin
                    if (match_2) begin
                        result_name_2 <= student2_name;
                        result_count <= result_count + 1;
                    end
                end
                LOAD_3: begin
                    if (match_3) begin
                        result_name_3 <= student3_name;
                        result_count <= result_count + 1;
                    end
                end
                DONE: begin
                    // Hold values, assert done
                    done <= 1;
                end
            endcase
        end
    end

endmodule
