module heap_sort(
    input wire clk,
    input wire rst_n,
    input wire start,
    input wire [7:0] arr [0:15],
    input wire [3:0] len,
    output reg [7:0] result [0:15],
    output reg done
);

    // State declarations
    localparam [1:0] IDLE    = 2'd0;
    localparam [1:0] BUILD   = 2'd1;
    localparam [1:0] EXTRACT = 2'd2;
    localparam [1:0] DONE_STATE = 2'd3;

    reg [1:0] state, next_state;
    reg [7:0] heap [0:15];
    reg [3:0] heap_size;
    reg [3:0] i_reg, j_reg;
    reg [3:0] build_index;
    reg [3:0] extract_index;
    reg [3:0] cycle_count;
    localparam [7:0] MAX_CYCLES = 8'd100;

    // Initialize all registers
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            next_state <= IDLE;
            done <= 1'b0;
            cycle_count <= 8'd0;
            heap_size <= 4'd0;
            i_reg <= 4'd0;
            j_reg <= 4'd0;
            build_index <= 4'd0;
            extract_index <= 4'd0;
            
            integer k;
            for (k = 0; k < 16; k = k + 1) begin
                heap[k] <= 8'd0;
                result[k] <= 8'd0;
            end
        end else begin
            state <= next_state;
            
            case (state)
                IDLE: begin
                    done <= 1'b0;
                    cycle_count <= 8'd0;
                    if (start) begin
                        next_state <= BUILD;
                        heap_size <= len;
                        
                        integer k;
                        for (k = 0; k < 16; k = k + 1) begin
                            heap[k] <= arr[k];
                        end
                    end
                end

                BUILD: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (build_index == 4'd0) begin
                        next_state <= EXTRACT;
                        extract_index <= len - 4'd1;
                    end else begin
                        build_index <= build_index - 4'd1;
                        i_reg <= build_index;
                        j_reg <= build_index;
                    end
                end

                EXTRACT: begin
                    cycle_count <= cycle_count + 8'd1;
                    
                    if (extract_index == 4'd0) begin
                        next_state <= DONE_STATE;
                    end else begin
                        if (i_reg == 4'd0) begin
                            heap[0] <= heap[extract_index];
                            heap[extract_index] <= heap[0];
                            extract_index <= extract_index - 4'd1;
                            i_reg <= 4'd0;
                            j_reg <= 4'd0;
                        end
                    end
                end

                DONE_STATE: begin
                    done <= 1'b1;
                    next_state <= IDLE;
                    
                    integer k;
                    for (k = 0; k < 16; k = k + 1) begin
                        result[k] <= heap[k];
                    end
                end

                default: next_state <= IDLE;
            endcase
        end
    end

    // Heapify logic
    always @(*) begin
        if (state == BUILD || state == EXTRACT) begin
            if (i_reg < heap_size) begin
                reg [3:0] largest = i_reg;
                reg [3:0] left = i_reg * 4'd2 + 4'd1;
                reg [3:0] right = i_reg * 4'd2 + 4'd2;

                if (left < heap_size && heap[left] > heap[largest]) begin
                    largest = left;
                end

                if (right < heap_size && heap[right] > heap[largest]) begin
                    largest = right;
                end

                if (largest != i_reg) begin
                    reg [7:0] temp = heap[i_reg];
                    heap[i_reg] = heap[largest];
                    heap[largest] = temp;
                    i_reg = largest;
                end else begin
                    i_reg = 4'd0;
                end
            end
        end
    end

endmodule