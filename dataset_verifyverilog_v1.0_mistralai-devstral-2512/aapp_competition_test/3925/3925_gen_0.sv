module ZebraSolver(
    input clk,
    input rst_n,
    input start,
    input data_in,
    input data_valid,
    input [5:0] len_in,
    output reg [6:0] result,
    output reg done
);

    parameter MAX_LEN = 64;
    
    // State declarations
    localparam [1:0] IDLE  = 2'd0;
    localparam [1:0] RECV  = 2'd1;
    localparam [1:0] SCAN  = 2'd2;
    localparam [1:0] DONE  = 2'd3;
    
    reg [1:0] state, next_state;
    
    // Buffer to store input string
    reg [MAX_LEN-1:0] buffer;
    reg [5:0] buffer_idx;
    
    // Scan counters
    reg [6:0] scan_idx;
    reg [6:0] current_run;
    reg [6:0] max_run;
    reg [5:0] current_len;
    
    // Previous bit for comparison
    reg prev_bit;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            buffer <= 0;
            buffer_idx <= 0;
            scan_idx <= 0;
            current_run <= 0;
            max_run <= 0;
            current_len <= 0;
            prev_bit <= 0;
            result <= 0;
            done <= 0;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = state;
        case (state)
            IDLE: begin
                if (start) begin
                    next_state = RECV;
                    buffer_idx = 0;
                    current_len = len_in;
                end
            end
            
            RECV: begin
                if (data_valid) begin
                    buffer[buffer_idx] = data_in;
                    buffer_idx = buffer_idx + 1;
                    if (buffer_idx == len_in) begin
                        next_state = SCAN;
                        scan_idx = 0;
                        current_run = 1;
                        max_run = 1;
                        prev_bit = buffer[0];
                    end
                end
            end
            
            SCAN: begin
                if (scan_idx < 2 * len_in - 1) begin
                    reg [5:0] current_pos = scan_idx % len_in;
                    reg [5:0] prev_pos = (scan_idx - 1) % len_in;
                    
                    if (buffer[current_pos] != buffer[prev_pos]) begin
                        current_run = current_run + 1;
                        if (current_run > max_run) begin
                            max_run = current_run;
                        end
                    end else begin
                        current_run = 1;
                    end
                    
                    scan_idx = scan_idx + 1;
                end else begin
                    next_state = DONE;
                    result = max_run;
                    if (max_run > len_in) begin
                        result = len_in;
                    end
                end
            end
            
            DONE: begin
                done = 1;
                next_state = IDLE;
            end
            
            default: next_state = IDLE;
        endcase
    end

endmodule