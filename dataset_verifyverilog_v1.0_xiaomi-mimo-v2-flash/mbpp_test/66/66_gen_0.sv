module pos_counter (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:7],
    input wire [3:0] len,
    output reg [15:0] result,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROC = 2'd1;
    localparam [1:0] DONE = 2'd2;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] idx;
    reg [3:0] cnt;
    reg [7:0] cycle_count;
    reg [3:0] actual_len;
    reg [7:0] temp_val;
    reg processing_done;

    // Combinational logic to determine actual length and processing complete
    always @(*) begin
        // Clamp length to max 8
        if (len > 8'd8) begin
            actual_len = 4'd8;
        end else if (len == 4'd0) begin
            actual_len = 4'd8;
        end else begin
            actual_len = len;
        end

        // Check if current index is within bounds
        if (idx < actual_len) begin
            processing_done = 1'b0;
        end else begin
            processing_done = 1'b1;
        end
    end

    // State transition and output logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            result <= 16'd0;
            done <= 1'b0;
            idx <= 3'd0;
            cnt <= 4'd0;
            cycle_count <= 8'd0;
            temp_val <= 8'd0;
        end else begin
            // Default assignments
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    idx <= 3'd0;
                    cnt <= 4'd0;
                    result <= 16'd0;
                    if (start) begin
                        state <= PROC;
                    end
                end

                PROC: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    // Check if processing is done or timeout
                    if (processing_done || (cycle_count >= MAX_CYCLES)) begin
                        state <= DONE;
                    end else begin
                        // Process current element
                        temp_val <= arr[idx];
                        
                        // Check if value is non-negative (MSB = 0)
                        if (arr[idx][7] == 1'b0) begin
                            cnt <= cnt + 4'd1;
                        end
                        
                        // Increment index
                        idx <= idx + 3'd1;
                    end
                end

                DONE: begin
                    result <= {12'd0, cnt};  // Result is the count
                    done <= 1'b1;
                    state <= IDLE;
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule