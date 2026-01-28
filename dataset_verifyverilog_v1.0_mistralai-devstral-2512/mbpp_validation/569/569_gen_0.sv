module string_sublist_sorter(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] data_in,
    input wire valid_in,
    input wire sublist_end,
    input wire list_end,
    output reg [7:0] data_out,
    output reg valid_out,
    output reg out_sublist_end,
    output reg out_list_end,
    output reg busy,
    output reg done
);

// Parameters
localparam [3:0] MAX_SUBLISTS = 4'd16;
localparam [2:0] MAX_SUBLIST_SIZE = 3'd4;
localparam [5:0] MAX_TOTAL_CHARS = 6'd64;

// Internal memory
reg [7:0] char_data [0:MAX_TOTAL_CHARS-1];
reg [5:0] sublist_start [0:MAX_SUBLISTS-1];
reg [3:0] sublist_size [0:MAX_SUBLISTS-1];

// Counters
reg [5:0] input_idx;
reg [3:0] sublist_count;
reg [3:0] current_sublist;
reg [3:0] current_size;
reg [5:0] current_start;

// Bubble sort state
reg [2:0] pass;
reg [2:0] compare;
reg [7:0] temp_a, temp_b;

// Output state
reg [5:0] output_idx;
reg [3:0] output_sublist;
reg [3:0] output_pos;

// FSM states
localparam [3:0] IDLE = 4'd0;
localparam [3:0] STORE = 4'd1;
localparam [3:0] SORT_INIT = 4'd2;
localparam [3:0] SORT_LOOP = 4'd3;
localparam [3:0] SORT_CMP = 4'd4;
localparam [3:0] SORT_SWAP = 4'd5;
localparam [3:0] SORT_DONE = 4'd6;
localparam [3:0] OUTPUT = 4'd7;
localparam [3:0] COMPLETE = 4'd8;

reg [3:0] state;

// State transition
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        state <= IDLE;
    end else begin
        case (state)
            IDLE: state <= start ? STORE : IDLE;
            STORE: begin
                if (list_end && !valid_in) state <= SORT_INIT;
                else state <= STORE;
            end
            SORT_INIT: state <= SORT_LOOP;
            SORT_LOOP: begin
                if (current_sublist >= sublist_count) state <= OUTPUT;
                else if (pass >= current_size - 1) state <= SORT_DONE;
                else if (compare < current_size - pass - 1) state <= SORT_CMP;
                else state <= SORT_LOOP;
            end
            SORT_CMP: state <= SORT_SWAP;
            SORT_SWAP: state <= SORT_LOOP;
            SORT_DONE: state <= SORT_INIT;
            OUTPUT: begin
                if (output_sublist >= sublist_count) state <= COMPLETE;
                else state <= OUTPUT;
            end
            COMPLETE: state <= IDLE;
            default: state <= IDLE;
        endcase
    end
end

// Control signals and counters
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        input_idx <= 6'd0;
        sublist_count <= 4'd0;
        current_sublist <= 4'd0;
        current_size <= 3'd0;
        current_start <= 6'd0;
        pass <= 3'd0;
        compare <= 3'd0;
        output_idx <= 6'd0;
        output_sublist <= 4'd0;
        output_pos <= 3'd0;
        // Clear memory
        integer i;
        for (i = 0; i < MAX_TOTAL_CHARS; i = i + 1) begin
            char_data[i] <= 8'd0;
        end
        for (i = 0; i < MAX_SUBLISTS; i = i + 1) begin
            sublist_start[i] <= 6'd0;
            sublist_size[i] <= 3'd0;
        end
    end else begin
        case (state)
            STORE: begin
                if (valid_in) begin
                    char_data[input_idx] <= data_in;
                    input_idx <= input_idx + 6'd1;
                end
                if (sublist_end && valid_in) begin
                    sublist_size[sublist_count] <= input_idx - sublist_start[sublist_count] + 3'd1;
                    sublist_count <= sublist_count + 4'd1;
                    if (sublist_count + 4'd1 < MAX_SUBLISTS) begin
                        sublist_start[sublist_count + 4'd1] <= input_idx + 6'd1;
                    end
                end
                if (list_end && valid_in) begin
                    sublist_size[sublist_count] <= input_idx - sublist_start[sublist_count] + 3'd1;
                    sublist_count <= sublist_count + 4'd1;
                end
            end
            SORT_INIT: begin
                if (current_sublist < sublist_count) begin
                    current_size <= sublist_size[current_sublist];
                    current_start <= sublist_start[current_sublist];
                    pass <= 3'd0;
                    compare <= 3'd0;
                end
            end
            SORT_LOOP: begin
                if (current_sublist < sublist_count) begin
                    if (pass < current_size - 3'd1) begin
                        if (compare < current_size - pass - 3'd1) begin
                            // Ready for comparison
                        end else begin
                            compare <= 3'd0;
                            pass <= pass + 3'd1;
                        end
                    end
                end
            end
            SORT_CMP: begin
                temp_a <= char_data[current_start + compare];
                temp_b <= char_data[current_start + compare + 3'd1];
            end
            SORT_SWAP: begin
                if (temp_a > temp_b) begin
                    char_data[current_start + compare] <= temp_b;
                    char_data[current_start + compare + 3'd1] <= temp_a;
                end
                compare <= compare + 3'd1;
            end
            SORT_DONE: begin
                current_sublist <= current_sublist + 4'd1;
            end
            OUTPUT: begin
                if (output_sublist < sublist_count) begin
                    output_idx <= current_start + output_pos;
                    output_pos <= output_pos + 3'd1;
                    if (output_pos + 3'd1 >= current_size) begin
                        output_pos <= 3'd0;
                        output_sublist <= output_sublist + 4'd1;
                        if (output_sublist + 4'd1 < sublist_count) begin
                            current_start <= sublist_start[output_sublist + 4'd1];
                            current_size <= sublist_size[output_sublist + 4'd1];
                        end
                    end
                end
            end
            COMPLETE: begin
                input_idx <= 6'd0;
                sublist_count <= 4'd0;
                current_sublist <= 4'd0;
                output_idx <= 6'd0;
                output_sublist <= 4'd0;
                output_pos <= 3'd0;
            end
        endcase
    end
end

// Output logic
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        data_out <= 8'd0;
        valid_out <= 1'b0;
        out_sublist_end <= 1'b0;
        out_list_end <= 1'b0;
        busy <= 1'b0;
        done <= 1'b0;
    end else begin
        case (state)
            IDLE: begin
                busy <= 1'b0;
                done <= 1'b0;
                valid_out <= 1'b0;
                out_sublist_end <= 1'b0;
                out_list_end <= 1'b0;
            end
            STORE, SORT_INIT, SORT_LOOP, SORT_CMP, SORT_SWAP, SORT_DONE: begin
                busy <= 1'b1;
                done <= 1'b0;
                valid_out <= 1'b0;
                out_sublist_end <= 1'b0;
                out_list_end <= 1'b0;
            end
            OUTPUT: begin
                busy <= 1'b1;
                done <= 1'b0;
                valid_out <= 1'b1;
                data_out <= char_data[output_idx];
                out_sublist_end <= (output_pos == current_size - 3'd1);
                out_list_end <= (output_sublist == sublist_count - 4'd1) &&
                               (output_pos == current_size - 3'd1);
            end
            COMPLETE: begin
                busy <= 1'b0;
                done <= 1'b1;
                valid_out <= 1'b0;
                out_sublist_end <= 1'b0;
                out_list_end <= 1'b0;
            end
            default: begin
                busy <= 1'b0;
                done <= 1'b0;
                valid_out <= 1'b0;
            end
        endcase
    end
end

endmodule