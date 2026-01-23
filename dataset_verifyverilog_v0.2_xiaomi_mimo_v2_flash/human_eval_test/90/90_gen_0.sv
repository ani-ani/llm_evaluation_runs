module next_smallest(
    input clk,
    input rst_n,
    input start,
    input [2:0] num_elements,
    input [7:0] data_in,
    input data_valid,
    output reg [7:0] result,
    output reg done,
    output reg valid
);

    // States
    localparam S_IDLE = 3'b000;
    localparam S_COLLECT = 3'b001;
    localparam S_PROCESS = 3'b010;
    localparam S_DONE = 3'b011;

    reg [2:0] state;
    reg [2:0] next_state;
    
    // Buffer storage
    reg [7:0] buffer [0:7];
    reg [2:0] write_ptr;
    reg [2:0] next_write_ptr;
    reg [2:0] read_ptr; // for PROCESS state
    reg [2:0] next_read_ptr;
    
    // Min registers
    reg [7:0] min1;
    reg [7:0] next_min1;
    reg [7:0] min2;
    reg [7:0] next_min2;
    
    // Flags to track if min1/min2 are valid (to handle "distinct" and empty)
    reg min1_set;
    reg next_min1_set;
    reg min2_set;
    reg next_min2_set;

    // State Register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            write_ptr <= 3'b0;
            read_ptr <= 3'b0;
            min1 <= 8'sd0;
            min2 <= 8'sd0;
            min1_set <= 1'b0;
            min2_set <= 1'b0;
            result <= 8'hFF;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            state <= next_state;
            write_ptr <= next_write_ptr;
            read_ptr <= next_read_ptr;
            min1 <= next_min1;
            min2 <= next_min2;
            min1_set <= next_min1_set;
            min2_set <= next_min2_set;
            // Buffer write happens here based on state logic
            if (state == S_COLLECT && data_valid) begin
                buffer[write_ptr] <= data_in;
            end
        end
    end

    // Combinational Logic
    always @(*) begin
        // Defaults
        next_state = state;
        next_write_ptr = write_ptr;
        next_read_ptr = read_ptr;
        next_min1 = min1;
        next_min2 = min2;
        next_min1_set = min1_set;
        next_min2_set = min2_set;

        case (state)
            S_IDLE: begin
                if (start) begin
                    if (num_elements == 0) next_state = S_DONE;
                    else next_state = S_COLLECT;
                end
            end
            S_COLLECT: begin
                if (data_valid) begin
                    next_write_ptr = write_ptr + 1;
                    if (next_write_ptr == num_elements) begin
                        next_state = S_PROCESS;
                    end
                end
            end
            S_PROCESS: begin
                if (read_ptr < num_elements) begin
                    // Update logic
                    if (!min1_set) begin
                        next_min1 = buffer[read_ptr];
                        next_min1_set = 1'b1;
                    end else if (buffer[read_ptr] < min1) begin
                        next_min2 = min1;
                        next_min2_set = min1_set;
                        next_min1 = buffer[read_ptr];
                    end else if (buffer[read_ptr] > min1) begin
                        if (!min2_set || buffer[read_ptr] < min2) begin
                            next_min2 = buffer[read_ptr];
                            next_min2_set = 1'b1;
                        end
                    end
                    next_read_ptr = read_ptr + 1;
                end else begin
                    next_state = S_DONE;
                end
            end
            S_DONE: begin
                if (start) next_state = S_IDLE;
            end
        endcase
    end

    // Output Register Logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            result <= 8'hFF;
            done <= 1'b0;
            valid <= 1'b0;
        end else begin
            // Buffer Write
            if (state == S_COLLECT && data_valid) begin
                buffer[write_ptr] <= data_in;
            end
            
            // State update is handled by the registers declared at the top.
            state <= next_state;
            write_ptr <= next_write_ptr;
            read_ptr <= next_read_ptr;
            min1 <= next_min1;
            min2 <= next_min2;
            min1_set <= next_min1_set;
            min2_set <= next_min2_set;

            // Output handling
            if (next_state == S_DONE) begin
                done <= 1'b1;
                valid <= 1'b1;
                if (num_elements < 2 || !next_min2_set) begin
                    result <= 8'hFF;
                end else begin
                    result <= next_min2;
                end
            end else begin
                done <= 1'b0;
                valid <= 1'b0;
            end
        end
    end

endmodule