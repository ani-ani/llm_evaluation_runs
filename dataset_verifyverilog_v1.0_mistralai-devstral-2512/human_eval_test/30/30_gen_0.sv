module filter_positives (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr_in[0:15],
    input wire [3:0] len_in,
    output reg [7:0] result[0:15],
    output reg [3:0] len_out,
    output reg done
);

    // State definitions
    localparam [1:0] IDLE = 2'd0;
    localparam [1:0] PROCESSING = 2'd1;
    localparam [1:0] DONE_STATE = 2'd2;

    // State register
    reg [1:0] state, next_state;

    // Counters
    reg [3:0] idx;
    reg [3:0] out_idx;

    // Input buffer
    reg [7:0] arr_buf[0:15];
    reg [3:0] len_buf;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            len_out <= 4'd0;
            idx <= 4'd0;
            out_idx <= 4'd0;
            len_buf <= 4'd0;
            // Initialize result array
            integer i;
            for (i = 0; i < 16; i = i + 1) begin
                result[i] <= 8'd0;
                arr_buf[i] <= 8'd0;
            end
        end else begin
            state <= next_state;
        end
    end

    // Next state logic
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    // Capture inputs
                    len_buf = len_in;
                    integer i;
                    for (i = 0; i < 16; i = i + 1) begin
                        arr_buf[i] = arr_in[i];
                    end
                    
                    // Handle len_in = 0 case
                    if (len_in == 4'd0) begin
                        next_state = DONE_STATE;
                    end else begin
                        idx = 4'd0;
                        out_idx = 4'd0;
                        next_state = PROCESSING;
                    end
                end
            end
            
            PROCESSING: begin
                // Process current element
                if (arr_buf[idx][7] == 1'b0 && arr_buf[idx] != 8'd0) begin
                    result[out_idx] = arr_buf[idx];
                    out_idx = out_idx + 4'd1;
                end
                
                // Check if done
                if (idx == len_buf - 4'd1) begin
                    len_out = out_idx;
                    next_state = DONE_STATE;
                end else begin
                    idx = idx + 4'd1;
                end
            end
            
            DONE_STATE: begin
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

    // Done signal logic
    always @(*) begin
        case (state)
            IDLE: done = 1'b0;
            PROCESSING: done = 1'b0;
            DONE_STATE: done = 1'b1;
            default: done = 1'b0;
        endcase
    end

endmodule