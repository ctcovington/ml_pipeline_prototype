def flatten(list):
    '''
    Given a list, possibly nested to any level, return it flattened
    '''
    new_list = []
    for item in list:
        if type(item) == type([]):
            new_list.extend(flatten(item))
        else:
            new_list.append(item)
    return new_list
