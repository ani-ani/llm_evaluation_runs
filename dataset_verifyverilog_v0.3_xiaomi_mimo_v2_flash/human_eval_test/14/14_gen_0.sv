module all_prefixes(
    input clk,
    input rst_n,
    input start,
    input [7:0] str [0:7],
    input [3:0] len,
    output reg [7:0] prefix [0:7],
    output reg [3:0] prefix_len,
    output reg valid,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // Internal state registers
    reg [1:0] state;
    reg [1:0] next_state;
    reg [3:0] current_len;
    reg [2:0] i; // Loop counter for array copy

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
                else
                    next_state = IDLE;
            end
            PROCESSING: begin
                if (current_len == len)
                    next_state = DONE_STATE;
                else
                    next_state = PROCESSING;
            end
            DONE_STATE: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            current_len <= 4'd0;
            valid <= 1'b0;
            done <= 1'b0;
            prefix_len <= 4'd0;
            // Initialize all prefix array elements to zero
            for (i = 0; i < 8; i = i + 1) begin
                prefix[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
            valid <= 1'b0;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    if (start) begin
                        current_len <= 4'd1;
                        // Load first character into prefix array
                        prefix[0] <= str[0];
                        // Reset other elements (just in case)
                        for (i = 1; i < 8; i = i + 1) begin
                            prefix[i] <= 8'd0;
                        end
                        prefix_len <= 4'd1;
                        valid <= 1'b1;
                    end
                end
                
                PROCESSING: begin
                    if (current_len < len) begin
                        // Generate next prefix
                        current_len <= current_len + 4'd1;
                        prefix_len <= current_len + 4'd1;
                        
                        // Copy string elements up to current_len
                        // We need to copy str[0:current_len] into prefix[0:current_len]
                        // Since we can't use for loops for array assignment in always block,
                        // we'll handle this with direct assignments
                        case (current_len + 4'd1)
                            4'd1: begin
                                prefix[0] <= str[0];
                                for (i = 1; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd2: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                for (i = 2; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd3: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                prefix[2] <= str[2];
                                for (i = 3; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd4: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                prefix[2] <= str[2];
                                prefix[3] <= str[3];
                                for (i = 4; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd5: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                prefix[2] <= str[2];
                                prefix[3] <= str[3];
                                prefix[4] <= str[4];
                                for (i = 5; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd6: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                prefix[2] <= str[2];
                                prefix[3] <= str[3];
                                prefix[4] <= str[4];
                                prefix[5] <= str[5];
                                for (i = 6; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd7: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                prefix[2] <= str[2];
                                prefix[3] <= str[3];
                                prefix[4] <= str[4];
                                prefix[5] <= str[5];
                                prefix[6] <= str[6];
                                for (i = 7; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                            4'd8: begin
                                prefix[0] <= str[0];
                                prefix[1] <= str[1];
                                prefix[2] <= str[2];
                                prefix[3] <= str[3];
                                prefix[4] <= str[4];
                                prefix[5] <= str[5];
                                prefix[6] <= str[6];
                                prefix[7] <= str[7];
                            end
                            default: begin
                                for (i = 0; i < 8; i = i + 1) begin
                                    prefix[i] <= 8'd0;
                                end
                            end
                        endcase
                        valid <= 1'b1;
                    end
                end
                
                DONE_STATE: begin
                    done <= 1'b1;
                end
                
                default: begin
                    // Reset to idle state
                    current_len <= 4'd0;
                    for (i = 0; i < 8; i = i + 1) begin
                        prefix[i] <= 8'd0;
                    end
                    prefix_len <= 4'd0;
                end
            endcase
        end
    end

endmodule