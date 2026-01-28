module sort_sublists (
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [127:0] str_data,
    input wire [15:0] sublist_lens,
    output reg [127:0] result,
    output reg done
);

    // State definitions
    localparam [2:0] IDLE     = 3'd0;
    localparam [2:0] EXTRACT  = 3'd1;
    localparam [2:0] SORT     = 3'd2;
    localparam [2:0] PACK     = 3'd3;
    localparam [2:0] FINISH   = 3'd4;

    reg [2:0] state, next_state;
    reg [7:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd200;

    // Registers for extracted strings (4 sublists x 4 strings max x 64 bits)
    reg [63:0] sublist_0 [0:3];
    reg [63:0] sublist_1 [0:3];
    reg [63:0] sublist_2 [0:3];
    reg [63:0] sublist_3 [0:3];
    
    // Registers for sorted strings
    reg [63:0] sorted_0 [0:3];
    reg [63:0] sorted_1 [0:3];
    reg [63:0] sorted_2 [0:3];
    reg [63:0] sorted_3 [0:3];
    
    // Extraction counter
    reg [1:0] extract_idx;
    reg [1:0] sublist_idx;
    
    // Sorting state for insertion sort
    reg [1:0] sort_i;
    reg [1:0] sort_j;
    reg [63:0] temp_key;
    reg [1:0] current_sublist;
    reg [1:0] insert_pos;
    
    // Packing counter
    reg [3:0] pack_idx;
    
    integer i, j;

    // Sublist lengths extraction
    wire [3:0] lens_0;
    wire [3:0] lens_1;
    wire [3:0] lens_2;
    wire [3:0] lens_3;
    
    assign lens_0 = sublist_lens[3:0];
    assign lens_1 = sublist_lens[7:4];
    assign lens_2 = sublist_lens[11:8];
    assign lens_3 = sublist_lens[15:12];

    // State transition logic
    always @(*) begin
        case (state)
            IDLE: begin
                if (start)
                    next_state = EXTRACT;
                else
                    next_state = IDLE;
            end
            EXTRACT: begin
                if ((extract_idx == 2'd3) && (sublist_idx == 2'd3))
                    next_state = SORT;
                else
                    next_state = EXTRACT;
            end
            SORT: begin
                // Sort completes when all 4 sublists done
                if ((current_sublist == 2'd3) && (sort_i == 2'd3))
                    next_state = PACK;
                else
                    next_state = SORT;
            end
            PACK: begin
                if (pack_idx == 4'd15)
                    next_state = FINISH;
                else
                    next_state = PACK;
            end
            FINISH: begin
                next_state = IDLE;
            end
            default: next_state = IDLE;
        endcase
    end

    // Sequential logic
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            done <= 1'b0;
            result <= 128'd0;
            cycle_count <= 8'd0;
            extract_idx <= 2'd0;
            sublist_idx <= 2'd0;
            sort_i <= 2'd0;
            sort_j <= 2'd0;
            current_sublist <= 2'd0;
            insert_pos <= 2'd0;
            pack_idx <= 4'd0;
            temp_key <= 64'd0;
            
            // Initialize all sublist registers
            for (i = 0; i < 4; i = i + 1) begin
                sublist_0[i] <= 64'd0;
                sublist_1[i] <= 64'd0;
                sublist_2[i] <= 64'd0;
                sublist_3[i] <= 64'd0;
                sorted_0[i] <= 64'd0;
                sorted_1[i] <= 64'd0;
                sorted_2[i] <= 64'd0;
                sorted_3[i] <= 64'd0;
            end
        end else begin
            state <= next_state;
            cycle_count <= cycle_count + 8'd1;
            done <= 1'b0;
            
            case (state)
                IDLE: begin
                    cycle_count <= 8'd0;
                    if (start) begin
                        // Start extraction
                        extract_idx <= 2'd0;
                        sublist_idx <= 2'd0;
                    end
                end
                
                EXTRACT: begin
                    // Extract current string from input
                    if (sublist_idx == 2'd0) begin
                        if (extract_idx < lens_0)
                            sublist_0[extract_idx] <= str_data[(extract_idx * 64) +: 64];
                    end else if (sublist_idx == 2'd1) begin
                        if (extract_idx < lens_1)
                            sublist_1[extract_idx] <= str_data[(extract_idx * 64) +: 64];
                    end else if (sublist_idx == 2'd2) begin
                        if (extract_idx < lens_2)
                            sublist_2[extract_idx] <= str_data[(extract_idx * 64) +: 64];
                    end else begin
                        if (extract_idx < lens_3)
                            sublist_3[extract_idx] <= str_data[(extract_idx * 64) +: 64];
                    end
                    
                    // Increment counters
                    if (extract_idx == 2'd3) begin
                        extract_idx <= 2'd0;
                        if (sublist_idx == 2'd3)
                            sublist_idx <= 2'd0;
                        else
                            sublist_idx <= sublist_idx + 2'd1;
                    end else begin
                        extract_idx <= extract_idx + 2'd1;
                    end
                end
                
                SORT: begin
                    // Insertion sort logic
                    // Copy current sublist to sorted registers
                    if (current_sublist == 2'd0) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            sorted_0[i] <= sublist_0[i];
                        end
                    end else if (current_sublist == 2'd1) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            sorted_1[i] <= sublist_1[i];
                        end
                    end else if (current_sublist == 2'd2) begin
                        for (i = 0; i < 4; i = i + 1) begin
                            sorted_2[i] <= sublist_2[i];
                        end
                    end else begin
                        for (i = 0; i < 4; i = i + 1) begin
                            sorted_3[i] <= sublist_3[i];
                        end
                    end
                    
                    // Actual insertion sort (one element per cycle)
                    // sort_i is the index of element being inserted
                    // sort_j is the index for shifting
                    if (sort_i < 2'd3) begin
                        // Get element from current sorted array
                        if (current_sublist == 2'd0) begin
                            temp_key <= sorted_0[sort_i + 2'd1];
                            // Find insertion position
                            for (j = 0; j < 4; j = j + 1) begin
                                if ((j <= sort_i) && (j < lens_0)) begin
                                    if (temp_key[7:0] < sorted_0[j][7:0]) begin
                                        // Shift elements right
                                        for (k = sort_i; k > j; k = k - 1) begin
                                            sorted_0[k + 2'd1] <= sorted_0[k];
                                        end
                                        sorted_0[j] <= temp_key;
                                    end
                                end
                            end
                        end else if (current_sublist == 2'd1) begin
                            temp_key <= sorted_1[sort_i + 2'd1];
                            for (j = 0; j < 4; j = j + 1) begin
                                if ((j <= sort_i) && (j < lens_1)) begin
                                    if (temp_key[7:0] < sorted_1[j][7:0]) begin
                                        for (k = sort_i; k > j; k = k - 1) begin
                                            sorted_1[k + 2'd1] <= sorted_1[k];
                                        end
                                        sorted_1[j] <= temp_key;
                                    end
                                end
                            end
                        end else if (current_sublist == 2'd2) begin
                            temp_key <= sorted_2[sort_i + 2'd1];
                            for (j = 0; j < 4; j = j + 1) begin
                                if ((j <= sort_i) && (j < lens_2)) begin
                                    if (temp_key[7:0] < sorted_2[j][7:0]) begin
                                        for (k = sort_i; k > j; k = k - 1) begin
                                            sorted_2[k + 2'd1] <= sorted_2[k];
                                        end
                                        sorted_2[j] <= temp_key;
                                    end
                                end
                            end
                        end else begin
                            temp_key <= sorted_3[sort_i + 2'd1];
                            for (j = 0; j < 4; j = j + 1) begin
                                if ((j <= sort_i) && (j < lens_3)) begin
                                    if (temp_key[7:0] < sorted_3[j][7:0]) begin
                                        for (k = sort_i; k > j; k = k - 1) begin
                                            sorted_3[k + 2'd1] <= sorted_3[k];
                                        end
                                        sorted_3[j] <= temp_key;
                                    end
                                end
                            end
                        end
                        sort_i <= sort_i + 2'd1;
                    end else begin
                        // Move to next sublist
                        sort_i <= 2'd0;
                        if (current_sublist == 2'd3)
                            current_sublist <= 2'd0;
                        else
                            current_sublist <= current_sublist + 2'd1;
                    end
                end
                
                PACK: begin
                    // Pack sorted strings back into output
                    case (pack_idx[3:2]) // Sublist index
                        2'd0: result[pack_idx * 8 +: 64] <= sorted_0[pack_idx[1:0]];
                        2'd1: result[pack_idx * 8 +: 64] <= sorted_1[pack_idx[1:0]];
                        2'd2: result[pack_idx * 8 +: 64] <= sorted_2[pack_idx[1:0]];
                        2'd3: result[pack_idx * 8 +: 64] <= sorted_3[pack_idx[1:0]];
                    endcase
                    pack_idx <= pack_idx + 4'd1;
                end
                
                FINISH: begin
                    done <= 1'b1;
                    // Reset counters for next operation
                    sort_i <= 2'd0;
                    current_sublist <= 2'd0;
                    pack_idx <= 4'd0;
                end
            endcase
        end
    end

endmodule