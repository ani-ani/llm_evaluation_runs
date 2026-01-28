module UntileableCellCounter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] street [0:15],
    input wire [3:0] pattern_len [0:7],
    input wire [7:0] patterns [0:7][0:15],
    input wire [3:0] M,
    output reg [15:0] result,
    output reg done
);

    // State declarations
    localparam [2:0] IDLE = 3'd0;
    localparam [2:0] PROCESS = 3'd1;
    localparam [2:0] COUNT = 3'd2;
    localparam [2:0] FINISH = 3'd3;

    reg [2:0] state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd250;

    reg [15:0] coverage_mask;
    reg [3:0] pattern_idx;
    reg [3:0] position_idx;
    reg [3:0] pattern_length;
    reg [7:0] pattern_char;
    reg [7:0] street_char;
    reg match;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            cycle_count <= 8'd0;
            coverage_mask <= 16'd0;
            pattern_idx <= 4'd0;
            position_idx <= 4'd0;
        end else begin
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        state <= PROCESS;
                        pattern_idx <= 4'd0;
                        position_idx <= 4'd0;
                        coverage_mask <= 16'd0;
                    end
                end

                PROCESS: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Get current pattern length
                    pattern_length = pattern_len[pattern_idx];
                    
                    // Check if we've processed all patterns
                    if (pattern_idx >= M) begin
                        state <= COUNT;
                    end else if (position_idx >= 16'd16 - pattern_length + 16'd1) begin
                        // Move to next pattern
                        pattern_idx <= pattern_idx + 4'd1;
                        position_idx <= 4'd0;
                    end else begin
                        // Check if pattern matches at current position
                        match = 1'b1;
                        for (integer i = 0; i < pattern_length; i = i + 1) begin
                            pattern_char = patterns[pattern_idx][i];
                            street_char = street[position_idx + i];
                            if (pattern_char != street_char) begin
                                match = 1'b0;
                            end
                        end
                        
                        // Update coverage mask if match found
                        if (match) begin
                            for (integer i = 0; i < pattern_length; i = i + 1) begin
                                coverage_mask[position_idx + i] = 1'b1;
                            end
                        end
                        
                        // Move to next position
                        position_idx <= position_idx + 4'd1;
                    end
                end

                COUNT: begin
                    // Count the number of zeros in coverage_mask
                    result = 16'd0;
                    for (integer i = 0; i < 16; i = i + 1) begin
                        if (!coverage_mask[i]) begin
                            result = result + 16'd1;
                        end
                    end
                    state <= FINISH;
                end

                FINISH: begin
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end
endmodule