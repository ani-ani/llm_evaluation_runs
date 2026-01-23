module min_heterogeneous (
    input clk,
    input rst_n, // active low
    input start,
    input [2:0] count,
    input [7:0] data_in,
    input load,
    output reg [7:0] min_result,
    output reg done,
    output reg error
);

// Internal registers
reg [7:0] data_array [7:0]; // 8 elements
reg [7:0] min_val;
reg [2:0] element_count; // number of elements loaded (up to count)
reg [2:0] load_timer; // counts 0-7 for 8 cycles in LOAD
reg [2:0] process_index; // index in processing, 0 to count-1
reg [2:0] process_timer; // counts 0-7 for 8 cycles in PROCESSING
reg [2:0] state; // 3 bits: 000=IDLE, 001=LOAD, 010=PROCESSING, 100=DONE

// State definitions (using numerical values)
localparam IDLE = 3'b000;
localparam LOAD_STATE = 3'b001;
localparam PROCESSING_STATE = 3'b010;
localparam DONE_STATE = 3'b100;

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_array <= 8'b0;
        min_val <= 8'hFF;
        element_count <= 3'b0;
        load_timer <= 3'b0;
        process_index <= 3'b0;
        process_timer <= 3'b0;
        state <= IDLE;
        done <= 1'b0;
        error <= 1'b0;
        min_result <= 8'h00; // initial value, doesn't matter
    end else begin
        case (state)
            IDLE: begin
                if (start) begin
                    state <= LOAD_STATE;
                    min_val <= 8'hFF;
                    element_count <= 3'b0;
                    load_timer <= 3'b0;
                    process_index <= 3'b0;
                    process_timer <= 3'b0;
                    done <= 1'b0;
                    error <= 1'b0;
                end
                else begin
                    state <= IDLE;
                end
            end
            LOAD_STATE: begin
                if (load_timer < 3'd7) begin
                    load_timer <= load_timer + 1;
                    if (load && element_count < count) begin
                        data_array[element_count] <= data_in;
                        element_count <= element_count + 1;
                    end
                end else begin // load_timer ==7, move to processing
                    state <= PROCESSING_STATE;
                end
            end
            PROCESSING_STATE: begin
                if (process_timer < 3'd7) begin
                    process_timer <= process_timer +1;
                    if (process_index < count) begin
                        if (data_array[process_index] < 8'hFF) begin
                            if (min_val > data_array[process_index] || min_val == 8'hFF) begin
                                min_val <= data_array[process_index];
                            end
                        end
                        process_index <= process_index +1;
                    end
                end else begin // process_timer ==7, done processing
                    if (min_val == 8'hFF) begin
                        error <= 1'b1;
                    end else begin
                        error <= 1'b0;
                    end
                    done <= 1'b1;
                    min_result <= min_val;
                    state <= DONE_STATE;
                end
            end
            DONE_STATE: begin
                // Remain in DONE state
                state <= DONE_STATE;
            end
        endcase
    end
end

endmodule