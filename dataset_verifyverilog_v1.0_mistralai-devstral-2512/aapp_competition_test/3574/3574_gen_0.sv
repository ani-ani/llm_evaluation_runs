module magical_subarray(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [2:0] query_l,
    input wire [2:0] query_r,
    input wire [7:0] array_data,
    input wire [2:0] array_addr,
    input wire array_wr,
    output reg [3:0] result,
    output reg done,
    output reg [2:0] state
);

    // State declarations
    localparam [2:0] IDLE       = 3'd0;
    localparam [2:0] LOADING    = 3'd1;
    localparam [2:0] PROCESSING = 3'd2;
    localparam [2:0] DONE_STATE = 3'd3;

    // Array storage (8x8-bit)
    reg [7:0] array [0:7];
    integer i;

    // Processing state
    reg [2:0] current_state, next_state;
    reg [2:0] query_left, query_right;
    reg [7:0] current_min, current_max;
    reg [3:0] current_length, max_length;
    reg [2:0] l_ptr, r_ptr;
    reg [2:0] query_counter;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // State machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= IDLE;
            result <= 4'd0;
            done <= 1'b0;
            state <= IDLE;
            cycle_count <= 8'd0;
            query_counter <= 3'd0;
            for (i = 0; i < 8; i = i + 1) begin
                array[i] <= 8'd0;
            end
        end else begin
            current_state <= next_state;
            state <= current_state;
            cycle_count <= cycle_count + 8'd1;

            // Array loading
            if (array_wr && current_state == IDLE) begin
                array[array_addr] <= array_data;
            end

            // State transitions
            case (current_state)
                IDLE: begin
                    done <= 1'b0;
                    if (start) begin
                        next_state <= PROCESSING;
                        query_left <= query_l;
                        query_right <= query_r;
                        max_length <= 4'd0;
                        l_ptr <= query_l;
                        r_ptr <= query_l;
                        query_counter <= 3'd0;
                    end else begin
                        next_state <= IDLE;
                    end
                end

                PROCESSING: begin
                    // Process current query
                    if (query_counter < 3'd8) begin
                        // Check if current subarray is magical
                        current_min <= array[l_ptr];
                        current_max <= array[r_ptr];
                        
                        // Check all elements in range
                        reg [7:0] temp_min, temp_max;
                        reg magical;
                        integer j;
                        
                        temp_min = array[l_ptr];
                        temp_max = array[r_ptr];
                        magical = 1'b1;
                        
                        for (j = l_ptr + 1; j <= r_ptr; j = j + 1) begin
                            if (array[j] < temp_min || array[j] > temp_max) begin
                                magical = 1'b0;
                            end
                        end
                        
                        current_length <= r_ptr - l_ptr + 4'd1;
                        
                        if (magical && current_length > max_length) begin
                            max_length <= current_length;
                        end
                        
                        // Move pointers
                        if (r_ptr < query_right) begin
                            r_ptr <= r_ptr + 3'd1;
                        end else begin
                            l_ptr <= l_ptr + 3'd1;
                            r_ptr <= l_ptr;
                            
                            if (l_ptr >= query_right) begin
                                // Query complete
                                result <= max_length;
                                query_counter <= query_counter + 3'd1;
                                l_ptr <= query_l;
                                r_ptr <= query_l;
                                max_length <= 4'd0;
                                
                                if (query_counter == 3'd7) begin
                                    next_state <= DONE_STATE;
                                end
                            end
                        end
                    end else begin
                        next_state <= DONE_STATE;
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                end

                default: begin
                    next_state <= IDLE;
                    done <= 1'b0;
                end
            endcase
        end
    end

    // Prevent infinite loops
    always @(posedge clk) begin
        if (cycle_count >= MAX_CYCLES) begin
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
        end
    end

endmodule