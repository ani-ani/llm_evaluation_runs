module right_insertion #(
    parameter N = 8
)(
    input reg [3:0] value,
    input reg [N-1:0][3:0] array,
    output reg [3:0] pos
);
    
    // Generate match vector: 1 if value <= array element
    wire [N-1:0] match;
    genvar i;
    for (i = 0; i < N; i = i + 1) begin : gen_match
        assign match[i] = (value <= array[i]);
    end
    
    // Extend match to 16 bits for processing
    wire [15:0] match_ext;
    assign match_ext = { {(16-N){1'b0}}, match };
    
    // Group signals for priority encoding
    wire [3:0] group_match;
    assign group_match[3] = |match_ext[15:12];
    assign group_match[2] = |match_ext[11:8];
    assign group_match[1] = |match_ext[7:4];
    assign group_match[0] = |match_ext[3:0];
    
    // Find highest non-empty group
    reg [3:0] group_index;
    always @(*) begin
        casez (group_match)
            4'b1???: group_index = 3;
            4'b01??: group_index = 2;
            4'b001?: group_index = 1;
            4'b0001: group_index = 0;
            default: group_index = 4;
        endcase
    end
    
    // Find local index within selected group
    reg [1:0] local_index;
    always @(*) begin
        case (group_index)
            3: begin
                casez (match_ext[15:12])
                    4'b1???: local_index = 3;
                    4'b01??: local_index = 2;
                    4'b001?: local_index = 1;
                    4'b0001: local_index = 0;
                endcase
            end
            2: begin
                casez (match_ext[11:8])
                    4'b1???: local_index = 3;
                    4'b01??: local_index = 2;
                    4'b001?: local_index = 1;
                    4'b0001: local_index = 0;
                endcase
            end
            1: begin
                casez (match_ext[7:4])
                    4'b1???: local_index = 3;
                    4'b01??: local_index = 2;
                    4'b001?: local_index = 1;
                    4'b0001: local_index = 0;
                endcase
            end
            0: begin
                casez (match_ext[3:0])
                    4'b1???: local_index = 3;
                    4'b01??: local_index = 2;
                    4'b001?: local_index = 1;
                    4'b0001: local_index = 0;
                endcase
            end
            default: local_index = 0;
        endcase
    end
    
    // Calculate final position
    always @(*) begin
        if (group_index == 4) begin
            pos = N;
        end else begin
            pos = group_index * 4 + local_index;
        end
    end
endmodule