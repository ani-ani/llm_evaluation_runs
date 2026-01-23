module incr_list (
    input clk,
    input rst_n,
    input start,
    input [2:0] length,
    input [7:0] data_in,
    input data_in_valid,
    output reg [7:0] data_out,
    output reg data_out_valid,
    output reg done
);

    // State definitions
    localparam IDLE = 2'b00;
    localparam PROCESSING = 2'b01;
    localparam DONE = 2'b10;

    // Internal registers
    reg [1:0] state, next_state;
    reg [2:0] count_in;   // Counter for input operations
    reg [2:0] count_out;  // Counter for output operations
    reg [7:0] mem [0:7];  // Memory array
    reg [3:0] i;          // Loop variable for loading memory
    
    // Combinational signals
    reg load_mem;
    reg inc_in_cnt;
    reg inc_out_cnt;
    reg clr_cnt;
    reg set_done;
    reg load_data;
    
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
        next_state = state;
        case (state)
            IDLE: begin
                if (start)
                    next_state = PROCESSING;
            end
            PROCESSING: begin
                // Transition to DONE when all elements are read and processed
                if (count_in == length && count_out == length && length != 0)
                    next_state = DONE;
                else if (length == 0)
                    next_state = DONE;
            end
            DONE: begin
                // Stay in DONE until reset or new start
                if (start)
                    next_state = PROCESSING;
            end
            default: next_state = IDLE;
        endcase
    end
    
    // Control signals logic
    always @(*) begin
        // Default values
        load_mem = 1'b0;
        inc_in_cnt = 1'b0;
        inc_out_cnt = 1'b0;
        clr_cnt = 1'b0;
        set_done = 1'b0;
        load_data = 1'b0;
        
        case (state)
            IDLE: begin
                if (start) begin
                    clr_cnt = 1'b1;
                end
            end
            PROCESSING: begin
                // Input phase
                if (count_in < length && data_in_valid) begin
                    load_mem = 1'b1;
                    inc_in_cnt = 1'b1;
                end
                
                // Output phase
                // Output starts after all inputs are read (or as they are read with delay)
                // According to spec: "reads length elements... outputs in following clock cycle"
                // And max latency is 2*length + 3, so output is delayed until inputs complete
                if (count_out < count_in) begin
                    load_data = 1'b1;
                    inc_out_cnt = 1'b1;
                end
            end
            DONE: begin
                set_done = 1'b1;
            end
        endcase
        
        // Handle length = 0 case
        if (state == PROCESSING && length == 0) begin
            set_done = 1'b1;
        end
    end
    
    // Memory write and counters
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count_in <= 3'b0;
            count_out <= 3'b0;
        end else begin
            if (state == IDLE && start) begin
                count_in <= 3'b0;
                count_out <= 3'b0;
            end else if (state == PROCESSING) begin
                if (load_mem) begin
                    mem[count_in] <= data_in;
                end
                if (inc_in_cnt) begin
                    count_in <= count_in + 1'b1;
                end
                if (inc_out_cnt) begin
                    count_out <= count_out + 1'b1;
                end
            end
        end
    end
    
    // Output generation
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= 8'b0;
            data_out_valid <= 1'b0;
            done <= 1'b0;
        end else begin
            // Output valid signal
            if (state == PROCESSING && load_data) begin
                data_out_valid <= 1'b1;
                data_out <= mem[count_out] + 8'd1;
            end else if (state == DONE || state == IDLE) begin
                data_out_valid <= 1'b0;
            end
            
            // Done signal
            if (state == DONE && !start) begin
                done <= 1'b1;
            end else begin
                done <= 1'b0;
            end
        end
    end

endmodule