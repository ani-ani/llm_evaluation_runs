module reverse_pairs_counter (
    input clk,
    input rst_n,
    input start,
    input [63:0] strings [0:7],
    input [3:0] len,
    output reg [3:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] REVERSE  = 3'd1;
    localparam [2:0] COMPARE  = 3'd2;
    localparam [2:0] DONE     = 3'd3;

    // Internal state registers
    reg [2:0] state;
    reg [2:0] next_state;
    reg [3:0] i;          // Outer loop index (0 to len-1)
    reg [3:0] j;          // Inner loop index (i to len-1)
    reg [3:0] k;          // Character index (0 to 7)
    reg [3:0] temp_result;
    reg [63:0] reversed_str;  // Reversed version of strings[i]
    reg [7:0] byte_i;          // Current byte from strings[i]
    reg match;                 // Match flag for current comparison
    reg [7:0] cycle_count;     // Timeout counter

    // Reverse operation: reverse 8 bytes in 64-bit string
    // strings[i] = {char7, char6, ..., char0}
    // reversed_str = {char0, char1, ..., char7}
    wire [63:0] reverse_wire;
    assign reverse_wire = {
        strings[i][7:0],
        strings[i][15:8],
        strings[i][23:16],
        strings[i][31:24],
        strings[i][39:32],
        strings[i][47:40],
        strings[i][55:48],
        strings[i][63:56]
    };

    // Next state logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = REVERSE;
                else
                    next_state = IDLE;
            end
            
            REVERSE: begin
                next_state = COMPARE;
            end
            
            COMPARE: begin
                if (k < 8'd8) begin
                    // Still comparing characters
                    next_state = COMPARE;
                end else if (j < len - 1) begin
                    // Move to next j
                    next_state = REVERSE;
                end else if (i < len - 1) begin
                    // Move to next i
                    next_state = REVERSE;
                end else begin
                    // All comparisons done
                    next_state = DONE;
                end
            end
            
            DONE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // State transition
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            i <= 4'd0;
            j <= 4'd0;
            k <= 4'd0;
            temp_result <= 4'd0;
            reversed_str <= 64'd0;
            match <= 1'b0;
            cycle_count <= 8'd0;
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        i <= 4'd0;
                        j <= 4'd0;
                        k <= 4'd0;
                        temp_result <= 4'd0;
                        match <= 1'b0;
                        reversed_str <= 64'd0;
                    end
                end
                
                REVERSE: begin
                    // Generate reversed version of strings[i]
                    reversed_str <= reverse_wire;
                    // Prepare for comparison: start comparing with j=i
                    // Reset k for character comparison
                    k <= 4'd0;
                    // Initialize match for new comparison
                    match <= 1'b1;
                    // Determine which j to compare against
                    // If we just came from COMPARE with j already set,
                    // we need to handle the j increment logic
                    // This state handles the transition logic
                    if (state == REVERSE && next_state == COMPARE) begin
                        // Already set up for comparison
                    end
                end
                
                COMPARE: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Compare characters
                    if (k < 8'd8) begin
                        // Get byte from strings[j] at position k
                        // strings[j] has 8 bytes: byte 0 is bits [7:0], byte 7 is [63:56]
                        // Get byte from reversed_str at position k
                        // reversed_str has bytes in reverse order
                        // byte k from reversed_str is at bits [k*8 +: 8]
                        
                        if (match) begin
                            // Only compare if still matching
                            if (strings[j][k*8 +: 8] != reversed_str[k*8 +: 8]) begin
                                match <= 1'b0;
                            end
                        end
                        k <= k + 4'd1;
                    end else begin
                        // Finished comparing all 8 characters
                        if (match) begin
                            // Strings match
                            temp_result <= temp_result + 4'd1;
                        end
                        
                        // Reset match for next comparison
                        match <= 1'b0;
                        
                        // Move to next comparison
                        if (j < len - 1) begin
                            // Move to next j
                            j <= j + 4'd1;
                            k <= 4'd0;
                            match <= 1'b1;
                        end else if (i < len - 1) begin
                            // Move to next i, reset j to i
                            i <= i + 4'd1;
                            j <= i + 4'd1;
                            k <= 4'd0;
                            match <= 1'b1;
                        end
                    end
                    
                    // Timeout check
                    if (cycle_count >= 8'd200) begin
                        state <= DONE;
                    end
                end
                
                DONE: begin
                    done <= 1'b1;
                    result <= temp_result;
                end
                
                default: begin
                    state <= IDLE;
                    result <= 4'd0;
                    done <= 1'b0;
                end
            endcase
        end
    end

endmodule