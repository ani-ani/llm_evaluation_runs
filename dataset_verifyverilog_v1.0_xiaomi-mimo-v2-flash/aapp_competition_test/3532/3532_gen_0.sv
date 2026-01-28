module StringExplosion(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] in_char,
    input wire [63:0] explosion_pattern,
    input wire [3:0] pattern_len,
    input wire [6:0] input_len,
    output reg [7:0] out_char,
    output reg out_valid,
    output reg done,
    output reg frula
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] OUTPUTING = 2'd2;
    localparam [1:0] FINISHED = 2'd3;

    // Registers and wires
    reg [1:0] state, next_state;
    reg [5:0] sp;  // Stack pointer (0-63)
    reg [5:0] sp_next;
    reg [6:0] input_counter;  // Counts 0 to input_len-1
    reg [6:0] input_counter_next;
    reg [5:0] output_counter;  // Counts 0 to sp-1
    reg [5:0] output_counter_next;
    reg [7:0] stack_reg [0:63];  // Stack memory
    reg [7:0] stack_reg_next [0:63];
    reg [5:0] pattern_idx;
    reg [5:0] pattern_idx_next;
    reg match_detected;
    reg [6:0] i;  // Loop variable for comparisons

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            sp <= 6'd0;
            input_counter <= 7'd0;
            output_counter <= 6'd0;
            out_char <= 8'd0;
            out_valid <= 1'b0;
            done <= 1'b0;
            frula <= 1'b0;
            pattern_idx <= 6'd0;
            // Initialize stack memory
            for (i = 0; i < 64; i = i + 1) begin
                stack_reg[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            sp <= sp_next;
            input_counter <= input_counter_next;
            output_counter <= output_counter_next;
            pattern_idx <= pattern_idx_next;
            // Update stack memory
            for (i = 0; i < 64; i = i + 1) begin
                stack_reg[i] <= stack_reg_next[i];
            end
        end
    end

    // Combinational logic
    always @(*) begin
        // Default assignments
        next_state = state;
        sp_next = sp;
        input_counter_next = input_counter;
        output_counter_next = output_counter;
        pattern_idx_next = pattern_idx;
        out_char = 8'd0;
        out_valid = 1'b0;
        done = 1'b0;
        frula = 1'b0;
        match_detected = 1'b0;
        
        // Default stack update (keep current values)
        for (i = 0; i < 64; i = i + 1) begin
            stack_reg_next[i] = stack_reg[i];
        end

        case (state)
            IDLE: begin
                if (start) begin
                    next_state = PROCESSING;
                    sp_next = 6'd0;
                    input_counter_next = 7'd0;
                    out_valid = 1'b0;
                    done = 1'b0;
                    frula = 1'b0;
                    // Clear stack
                    for (i = 0; i < 64; i = i + 1) begin
                        stack_reg_next[i] = 8'd0;
                    end
                end
            end

            PROCESSING: begin
                // Push current character
                if (input_counter < input_len) begin
                    stack_reg_next[sp] = in_char;
                    sp_next = sp + 6'd1;
                    input_counter_next = input_counter + 7'd1;
                    
                    // Check for explosion pattern
                    if (pattern_len > 4'd0 && sp >= pattern_len) begin
                        match_detected = 1'b1;
                        // Compare top pattern_len characters
                        for (i = 0; i < 8; i = i + 1) begin
                            if (i < pattern_len) begin
                                if (stack_reg[sp - pattern_len + i] != explosion_pattern[(i*8)+:8]) begin
                                    match_detected = 1'b0;
                                end
                            end
                        end
                        
                        if (match_detected) begin
                            sp_next = sp - pattern_len;
                        end
                    end
                end
                
                // Transition to OUTPUTING
                if (input_counter_next >= input_len) begin
                    next_state = OUTPUTING;
                    output_counter_next = 6'd0;
                end
            end

            OUTPUTING: begin
                if (output_counter < sp) begin
                    out_char = stack_reg[output_counter];
                    out_valid = 1'b1;
                    output_counter_next = output_counter + 6'd1;
                end else begin
                    next_state = FINISHED;
                    out_valid = 1'b0;
                    done = 1'b1;
                    // Check if result is empty (FRULA)
                    frula = (sp == 6'd0);
                end
            end

            FINISHED: begin
                done = 1'b1;
                frula = (sp == 6'd0);
                out_valid = 1'b0;
                // Wait for next start
                next_state = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

endmodule